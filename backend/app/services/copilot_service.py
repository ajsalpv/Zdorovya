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

# --- Define Tools ---

@tool
def query_medical_records(query_text: str, patient_id: str = None):
    """
    Search for medical records based on metadata like type (ECG, Blood Test).
    """
    try:
        req = supabase.from_('medical_records').select('*, family_members(name)')
        if patient_id:
            req = req.eq('patient_id', patient_id)
        
        res = req.ilike('type', f'%{query_text}%').execute()
        
        from .security_service import security_service
        records = res.data
        for r in records:
            if r.get('extracted_text'):
                r['extracted_text'] = security_service.decrypt_data(r['extracted_text'])
                
        return json.dumps(records)
    except Exception as e:
        return f"Error querying records: {e}"

@tool
def semantic_search_records(query_text: str, family_id: str = '00000000-0000-0000-0000-000000000000'):
    """
    Search for medical records using natural language semantic search.
    Best for finding conceptual info (e.g. 'renal issues', 'cardiac history').
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
        
        res = supabase.rpc('match_medical_records', {
            'query_embedding': query_embedding,
            'match_threshold': 0.4,
            'match_count': 5,
            'p_family_id': family_id
        }).execute()
        
        from .security_service import security_service
        records = res.data
        for r in records:
            if r.get('extracted_text'):
                r['extracted_text'] = security_service.decrypt_data(r['extracted_text'])
        
        return json.dumps(records)
    except Exception as e:
        return f"Error in semantic search: {e}"

@tool
def analyze_health_trends(metric_type: str = "glucose"):
    """
    Retrieve logs for health metrics like glucose or blood pressure.
    Returns the last 10 measurements to detect patterns.
    """
    try:
        res = supabase.from_('health_metrics').select('*').order('recorded_at', desc=True).limit(10).execute()
        return json.dumps(res.data)
    except Exception as e:
        return f"Error fetching trends: {e}"

@tool
def get_adherence_report():
    """
    Calculate medication adherence status from the latest logs.
    """
    try:
        res = supabase.from_('medicine_reminders').select('status, medicine_name, scheduled_time').limit(20).execute()
        return json.dumps(res.data)
    except Exception as e:
        return f"Error fetching adherence: {e}"

@tool
def emergency_summary(family_id: str = '00000000-0000-0000-0000-000000000000'):
    """
    CRITICAL: Instantly retrieve vital health data for emergencies.
    Includes blood group, active conditions, and latest prescriptions.
    """
    try:
        family = supabase.from_('family_members').select('*').limit(5).execute()
        meds = supabase.from_('medicines').select('name, dosage').limit(10).execute()
        records = supabase.from_('medical_records').select('type, extracted_text').order('record_date', desc=True).limit(3).execute()
        
        from .security_service import security_service
        clean_records = []
        for r in records.data:
            if r.get('extracted_text'):
                r['extracted_text'] = security_service.decrypt_data(r['extracted_text'])
            clean_records.append(r)
            
        return json.dumps({
            "vital_info": family.data,
            "active_medications": meds.data,
            "recent_medical_history": clean_records
        })
    except Exception as e:
        return f"Error gathering emergency data: {e}"

# --- LangGraph Setup ---

class AgentState(TypedDict):
    messages: Annotated[List[BaseMessage], "The conversation history"]

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
            analyze_health_trends, 
            get_adherence_report,
            emergency_summary
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
        return {"messages": [response]}

    async def chat(self, user_msg: str, session_id: str):
        config = {"configurable": {"thread_id": session_id}}
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        system_prompt = SystemMessage(content=f"""
        You are the Zdorovya Health Copilot, an advanced RAG-powered assistant.
        Current Date/Time: {current_time}
        
        TOOLS GUIDE:
        1. 'semantic_search_records': Use for vague or conceptual medical queries.
        2. 'query_medical_records': Use for exact document type lookups.
        3. 'analyze_health_trends': Use for sugar/BP pattern analysis.
        4. 'get_adherence_report': Use to check if meds are being taken.
        5. 'emergency_summary': Use ONLY when user mentions an emergency or needs vital info fast.
        
        Always explain medical terms simply. If records show abnormal values, highlight them clearly.
        If no data is found, admit it and suggest what the user can upload.
        """)

        result = await self.app.ainvoke(
            {"messages": [system_prompt, HumanMessage(content=user_msg)]}, 
            config
        )
        
        last_msg = result["messages"][-1]
        return {
            "text": last_msg.content,
            "session_id": session_id
        }

copilot_agent = CopilotAgent()
