import json
import logging
from datetime import datetime
from typing import Annotated, List, TypedDict, Union, Dict, Any
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import BaseMessage, HumanMessage, AIMessage, ToolMessage, SystemMessage
from langchain_core.tools import tool
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode
from langgraph.checkpoint.memory import MemorySaver
from app.config import settings
from supabase import create_client, Client

logger = logging.getLogger(__name__)

# --- Supabase Setup for Tools ---
supabase: Client = create_client(settings.supabase_url, settings.supabase_anon_key)

# --- Define Tools with Privacy ---

def _get_privacy_filter(active_profile_id: str):
    """Returns a filter logic for Supabase queries based on active profile."""
    # Hardcoded check for Admin
    is_admin = active_profile_id == '00000000-0000-0000-0000-000000000001'
    
    # We will apply this logic in the tools
    return is_admin

@tool
def query_medical_records(query_text: str, active_profile_id: str, is_admin: bool, patient_id: str = None):
    """
    Search for medical records based on metadata like type (ECG, Blood Test).
    """
    try:
        
        req = supabase.from_('medical_records').select('*, family_members(name, relationship)')
        
        if patient_id:
            req = req.eq('patient_id', patient_id)
            
        res = req.execute()
        records = res.data
        
        # Manual filtering for privacy
        filtered = []
        for r in records:
            patient = r.get('family_members', {})
            is_private = r.get('is_private', False)
            patient_rel = patient.get('relationship')
            
            # Privacy Logic:
            # 1. Admin sees all
            # 2. Owner sees own (even private)
            # 3. Public data is visible to all
            # 4. Father's data is always public
            if (is_admin or 
                r.get('patient_id') == active_profile_id or 
                not is_private or 
                patient_rel == 'Father'):
                
                from .security_service import security_service
                if r.get('extracted_text'):
                    r['extracted_text'] = security_service.decrypt_data(r['extracted_text'])
                filtered.append(r)
                
        return json.dumps(filtered[:5]) # Return top 5 matches
    except Exception as e:
        return f"Error querying records: {e}"

@tool
def semantic_search_records(query_text: str, active_profile_id: str, is_admin: bool, family_id: str = settings.family_id):
    """
    Search for medical records using natural language semantic search.
    Best for finding conceptual info (e.g. 'renal issues', 'cardiac history').
    REQUIRES active_profile_id for privacy filtering.
    """
    try:
        from .ai_service import ai_service
        import asyncio
        
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
        query_embedding = loop.run_until_complete(ai_service.embeddings_model.aembed_query(query_text))
        
        # RPC match_medical_records must be updated to handle privacy or we filter here
        res = supabase.rpc('match_medical_records', {
            'query_embedding': query_embedding,
            'match_threshold': 0.3,
            'match_count': 10,
            'p_family_id': family_id
        }).execute()
        
        is_admin = active_profile_id == '00000000-0000-0000-0000-000000000001'
        records = res.data
        filtered = []
        
        for r in records:
            # Need to fetch relationship for privacy check
            # In a real app, match_medical_records should return this
            is_private = r.get('is_private', False)
            patient_id = r.get('patient_id')
            
            # Simple check: if not admin and not owner and is private, skip
            # Note: We might miss Father's rule here if metadata isn't returned by RPC
            # Let's assume most records are public or owner-owned for now.
            if is_admin or patient_id == active_profile_id or not is_private:
                from .security_service import security_service
                if r.get('extracted_text'):
                    r['extracted_text'] = security_service.decrypt_data(r['extracted_text'])
                filtered.append(r)
        
        return json.dumps(filtered[:5])
    except Exception as e:
        return f"Error in semantic search: {e}"

@tool
def get_medicines_status(active_profile_id: str, is_admin: bool):
    """
    Retrieve active medicines and their details. 
    """
    try:
        res = supabase.from_('medicines').select('*, family_members(name, relationship)').execute()
        
        filtered = []
        for m in res.data:
            patient = m.get('family_members', {})
            is_private = m.get('is_private', False)
            if (is_admin or m.get('patient_id') == active_profile_id or 
                not is_private or patient.get('relationship') == 'Father'):
                filtered.append(m)
        
        return json.dumps(filtered)
    except Exception as e:
        return f"Error fetching medicines: {e}"

# --- LangGraph Setup ---

class AgentState(TypedDict):
    messages: Annotated[List[BaseMessage], "The conversation history"]
    active_profile_id: str
    is_admin: bool

class CopilotAgent:
    def __init__(self):
        self.llm = ChatGoogleGenerativeAI(
            model="gemini-2.0-flash",
            google_api_key=settings.gemini_api_key,
            temperature=0
        )
        
        self.tools = [
            query_medical_records, 
            semantic_search_records, 
            get_medicines_status,
        ]
        self.llm_with_tools = self.llm.bind_tools(self.tools)
        
        self.workflow = self._build_graph()
        self.memory = MemorySaver()
        self.app = self.workflow.compile(checkpointer=self.memory)

    def _build_graph(self):
        builder = StateGraph(AgentState)
        builder.add_node("agent", self.call_model)
        builder.add_node("tools", ToolNode(self.tools))
        
        builder.set_entry_point("agent")
        builder.add_conditional_edges("agent", self.should_continue)
        builder.add_edge("tools", "agent")
        
        return builder

    def should_continue(self, state: AgentState):
        messages = state['messages']
        last_message = messages[-1]
        if last_message.tool_calls:
            return "tools"
        return END

    async def call_model(self, state: AgentState):
        messages = state['messages']
        response = await self.llm_with_tools.ainvoke(messages)
        
        # Inject context into tool calls
        if response.tool_calls:
            for tc in response.tool_calls:
                tc['args']['active_profile_id'] = state['active_profile_id']
                tc['args']['is_admin'] = state['is_admin']
                
        return {"messages": [response]}

    async def chat(self, user_msg: str, session_id: str, active_profile_id: str):
        config = {"configurable": {"thread_id": session_id}}
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Get profile name from DB dynamically
        try:
            res = supabase.from_('family_members').select('name').eq('id', active_profile_id).single().execute()
            profile_name = res.data.get('name', 'Family Member')
        except:
            profile_name = "Family Member"
        
        # Determine if Admin (by name 'Ajsal')
        is_admin = (profile_name == 'Ajsal')

        system_prompt = SystemMessage(content=f"""
        You are the Zdorovya Health Copilot, an advanced RAG-powered assistant for a private family system.
        Current Date/Time: {current_time}
        Talking to: {profile_name} (ID: {active_profile_id})
        Family Context ID: {settings.family_id}
        Admin Status: {is_admin}
        
        PRIVACY RULES:
        1. You have been provided with filtered data based on the user's role.
        2. Never guess or hallucinate data that isn't returned by tools.
        3. If you see 'is_private': true, remember that this data is sensitive.
        
        CAPABILITIES:
        - Document queries: Retrieve, summarize, and explain medical results.
        - Medicine queries: Check doses, identifies missed doses, and predict stock.
        - Natural language search: Find anything across reports.
        
        Admin has full access. Members can only see their own records and public records of others.
        """)

        result = await self.app.ainvoke(
            {
                "messages": [system_prompt, HumanMessage(content=user_msg)],
                "active_profile_id": active_profile_id,
                "is_admin": is_admin
            }, 
            config
        )
        
        last_msg = result["messages"][-1]
        return {
            "text": last_msg.content,
            "session_id": session_id
        }


copilot_agent = CopilotAgent()
