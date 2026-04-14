import json
import logging
from datetime import datetime
from typing import Annotated, List, TypedDict, Union, Dict, Any
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import BaseMessage, HumanMessage, AIMessage, ToolMessage, SystemMessage
from langchain_core.tools import tool
from langgraph.graph import StateGraph, END, MessageGraph
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
    Search for medical records based on a natural language query.
    Returns metadata about reports like ECG, Blood Test, etc.
    """
    # In a real setup, we'd use semantic search or NL2SQL. 
    # For now, we perform a structured search on metadata.
    try:
        req = supabase.from_('medical_records').select('*, family_members(name)')
        if patient_id:
            req = req.eq('patient_id', patient_id)
        
        # Simple text search on type or extracted_text
        res = req.ilike('type', f'%{query_text}%').execute()
        return json.dumps(res.data)
    except Exception as e:
        return f"Error querying records: {e}"

@tool
def query_medicine_compliance(medicine_name: str):
    """
    Check if a specific medicine has been taken regularly.
    Returns a log of the last 5 reminder statuses.
    """
    try:
        # 1. Find medicine ID
        med_res = supabase.from_('medicines').select('id, name').ilike('name', f'%{medicine_name}%').execute()
        if not med_res.data:
            return "Medicine not found."
        
        med_id = med_res.data[0]['id']
        
        # 2. Get history
        history = supabase.from_('medicine_reminders').select('*').eq('medicine_id', med_id).order('created_at', desc=True).limit(5).execute()
        return json.dumps(history.data)
    except Exception as e:
        return f"Error checking compliance: {e}"

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
        
        # Bind tools to LLM
        self.tools = [query_medical_records, query_medicine_compliance]
        self.llm_with_tools = self.llm.bind_tools(self.tools)
        
        # Build Graph
        self.workflow = self._build_graph()
        self.memory = MemorySaver()
        self.app = self.workflow.compile(checkpointer=self.memory)

    def _build_graph(self):
        builder = StateGraph(AgentState)
        
        # Define Nodes
        builder.add_node("agent", self.call_model)
        builder.add_node("tools", ToolNode(self.tools))
        
        # Define Edges
        builder.set_entry_point("agent")
        builder.add_conditional_edges(
            "agent",
            self.should_continue,
        )
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
        You are the Zdorovya Health Copilot. 
        Current Date/Time: {current_time}
        Always use this time to contextually understand user queries about 'today', 'last week', etc.
        When users ask about medical history, use your tools to find the exact data.
        """)

        # Run graph with system prompt prepended for time awareness
        result = await self.app.ainvoke(
            {"messages": [system_prompt, HumanMessage(content=user_msg)]}, 
            config
        )
        
        last_msg = result["messages"][-1]
        
        # Format response
        # To support "embedded cards", we can instruct LLM to return a specific tag like [RECORD:id]
        return {
            "text": last_msg.content,
            "session_id": session_id
        }

copilot_agent = CopilotAgent()
