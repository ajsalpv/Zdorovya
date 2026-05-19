import json
import logging
import uuid
import contextvars
from datetime import datetime
from typing import Annotated, List, TypedDict
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import BaseMessage, HumanMessage, SystemMessage
from langchain_core.tools import tool
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode
from langgraph.checkpoint.memory import MemorySaver
from app.config import settings
from supabase import create_client, Client

logger = logging.getLogger(__name__)

# --- Supabase Setup ---
supabase: Client = create_client(settings.supabase_url, settings.supabase_anon_key)

# --- Context Variables for Tools ---
active_profile_id_var = contextvars.ContextVar("active_profile_id", default="")
is_admin_var = contextvars.ContextVar("is_admin", default=False)

def is_valid_uuid(val: str) -> bool:
    try:
        uuid.UUID(str(val))
        return True
    except (ValueError, TypeError):
        return False

# --- Tools (privacy enforced via context variables) ---

@tool
def query_medical_records(query_text: str, patient_id: str = None):
    """Search for medical records by type (ECG, Blood Test, Prescription, etc.)."""
    active_profile_id = active_profile_id_var.get()
    is_admin = is_admin_var.get()
    try:
        req = supabase.from_('medical_records').select('*, family_members(name, relationship)')
        
        if patient_id:
            if not is_valid_uuid(patient_id):
                # Try to lookup member by name
                logger.info(f"Looking up patient member by name: {patient_id}")
                member_res = supabase.from_('family_members').select('id').ilike('name', f"%{patient_id}%").execute()
                if member_res.data:
                    patient_id = member_res.data[0]['id']
                    logger.info(f"Resolved patient name to ID: {patient_id}")
                else:
                    # Try to lookup by relationship
                    rel_res = supabase.from_('family_members').select('id').ilike('relationship', f"%{patient_id}%").execute()
                    if rel_res.data:
                        patient_id = rel_res.data[0]['id']
                        logger.info(f"Resolved patient relationship to ID: {patient_id}")
                    else:
                        logger.warning(f"Could not resolve patient_id: {patient_id}")
                        patient_id = None
            
            if patient_id:
                req = req.eq('patient_id', patient_id)

        res = req.execute()

        filtered = []
        for r in res.data:
            patient = r.get('family_members', {}) or {}
            is_private = r.get('is_private', False)
            patient_rel = patient.get('relationship')

            if (is_admin or
                r.get('patient_id') == active_profile_id or
                not is_private or
                patient_rel == 'Father'):
                from .security_service import security_service
                if r.get('extracted_text'):
                    r['extracted_text'] = security_service.decrypt_data(r['extracted_text'])
                filtered.append(r)

        return json.dumps(filtered[:5])
    except Exception as e:
        return f"Error querying records: {e}"


@tool
def semantic_search_records(query_text: str, family_id: str = settings.family_id):
    """Search medical records using natural language (e.g. 'renal issues', 'cardiac history')."""
    active_profile_id = active_profile_id_var.get()
    is_admin = is_admin_var.get()
    try:
        from .ai_service import ai_service
        import asyncio

        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

        query_embedding = loop.run_until_complete(ai_service.embeddings_model.aembed_query(query_text))

        res = supabase.rpc('match_medical_records', {
            'query_embedding': query_embedding,
            'match_threshold': 0.3,
            'match_count': 10,
            'p_family_id': family_id
        }).execute()

        filtered = []
        for r in res.data:
            is_private = r.get('is_private', False)
            pid = r.get('patient_id')
            if is_admin or pid == active_profile_id or not is_private:
                from .security_service import security_service
                if r.get('extracted_text'):
                    r['extracted_text'] = security_service.decrypt_data(r['extracted_text'])
                filtered.append(r)

        return json.dumps(filtered[:5])
    except Exception as e:
        return f"Error in semantic search: {e}"


@tool
def get_medicines_status():
    """Retrieve active medicines and their details."""
    active_profile_id = active_profile_id_var.get()
    is_admin = is_admin_var.get()
    try:
        res = supabase.from_('medicines').select('*, family_members(name, relationship)').execute()

        filtered = []
        for m in res.data:
            patient = m.get('family_members', {}) or {}
            is_private = m.get('is_private', False)
            if (is_admin or m.get('patient_id') == active_profile_id or
                not is_private or patient.get('relationship') == 'Father'):
                filtered.append(m)

        return json.dumps(filtered)
    except Exception as e:
        return f"Error fetching medicines: {e}"


# --- LangGraph Agent ---

class AgentState(TypedDict):
    messages: Annotated[List[BaseMessage], "The conversation history"]
    active_profile_id: str
    is_admin: bool


def _create_llm(use_groq: bool = False):
    """Create an LLM instance. Falls back to Groq if requested or Gemini fails."""
    if use_groq and settings.groq_api_key:
        from langchain_groq import ChatGroq
        logger.info("Using Groq (llama-3.3-70b-versatile) as AI provider")
        return ChatGroq(
            model="llama-3.3-70b-versatile",
            api_key=settings.groq_api_key,
            temperature=0
        )
    logger.info("Using Gemini (gemini-2.0-flash) as AI provider")
    return ChatGoogleGenerativeAI(
        model="gemini-2.0-flash",
        google_api_key=settings.gemini_api_key,
        temperature=0
    )


class CopilotAgent:
    def __init__(self):
        self.tools = [query_medical_records, semantic_search_records, get_medicines_status]
        self.memory = MemorySaver()
        self._use_groq = False
        self._rebuild_graph()

    def _rebuild_graph(self):
        """Build or rebuild the LangGraph workflow with the current LLM."""
        self.llm = _create_llm(self._use_groq)
        self.llm_with_tools = self.llm.bind_tools(self.tools)

        builder = StateGraph(AgentState)
        builder.add_node("agent", self.call_model)
        builder.add_node("tools", ToolNode(self.tools))
        builder.set_entry_point("agent")
        builder.add_conditional_edges("agent", self.should_continue)
        builder.add_edge("tools", "agent")

        self.app = builder.compile(checkpointer=self.memory)

    def should_continue(self, state: AgentState):
        last_message = state['messages'][-1]
        if last_message.tool_calls:
            return "tools"
        return END

    async def call_model(self, state: AgentState):
        messages = state['messages']
        response = await self.llm_with_tools.ainvoke(messages)
        return {"messages": [response]}

    async def chat(self, user_msg: str, session_id: str, active_profile_id: str):
        config = {
            "configurable": {"thread_id": session_id},
            "recursion_limit": 50
        }
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        # Get profile name from DB dynamically
        try:
            res = supabase.from_('family_members').select('name').eq('id', active_profile_id).single().execute()
            profile_name = res.data.get('name', 'Family Member')
        except Exception:
            profile_name = "Family Member"

        # Admin check by name (only hardcoded value per user request)
        is_admin = (profile_name == 'Ajsal')

        # Set context variables for tools
        active_token = active_profile_id_var.set(active_profile_id)
        admin_token = is_admin_var.set(is_admin)

        system_prompt = SystemMessage(content=f"""
        You are the Zdorovya Health Copilot, an AI health assistant for a private family.
        Current Date/Time: {current_time}
        Talking to: {profile_name} (ID: {active_profile_id})
        Family ID: {settings.family_id}
        Admin: {is_admin}

        RULES:
        1. Only use data returned by tools. Never guess or hallucinate.
        2. Admin sees all records. Members see only their own + public records.
        3. Be concise, caring, and medically accurate.
        4. For prescriptions, always mention dosage and frequency clearly.
        """)

        # Try Gemini first, fall back to Groq on quota errors
        try:
            for attempt in range(2):
                try:
                    result = await self.app.ainvoke(
                        {
                            "messages": [system_prompt, HumanMessage(content=user_msg)],
                            "active_profile_id": active_profile_id,
                            "is_admin": is_admin
                        },
                        config
                    )
                    last_msg = result["messages"][-1]
                    return {"text": last_msg.content, "session_id": session_id}

                except Exception as e:
                    error_msg = str(e)
                    if ("429" in error_msg or "ResourceExhausted" in error_msg) and attempt == 0 and settings.groq_api_key:
                        logger.warning("Gemini quota hit, switching to Groq fallback")
                        self._use_groq = True
                        self._rebuild_graph()
                        continue
                    raise
        finally:
            active_profile_id_var.reset(active_token)
            is_admin_var.reset(admin_token)


copilot_agent = CopilotAgent()
