import json
import logging
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any, TypedDict
from pydantic import BaseModel, Field
from langchain_google_genai import ChatGoogleGenerativeAI, GoogleGenerativeAIEmbeddings
from langchain_core.messages import HumanMessage
from langgraph.graph import StateGraph, END
from app.config import settings

logger = logging.getLogger(__name__)

# --- Structured Output Schema ---

class Medicine(BaseModel):
    name: str = Field(description="Name of the medicine")
    dosage: Optional[str] = Field(default=None, description="Dosage, e.g., 500mg")
    frequency: Optional[str] = Field(default=None, description="Frequency, e.g., Twice a day")
    duration: Optional[str] = Field(default=None, description="Duration of treatment")
    quantity: Optional[str] = Field(default=None, description="Quantity purchased (for receipts)")
    price: Optional[str] = Field(default=None, description="Price (for receipts)")

class ExtractionResult(BaseModel):
    type: str = Field(description="ECG, Blood Test, Prescription, Receipt, etc.")
    patient_name: Optional[str] = Field(default=None, description="Name of the person")
    date: Optional[str] = Field(default=None, description="Document date in YYYY-MM-DD")
    doctor_name: Optional[str] = Field(default=None, description="Doctor or Hospital name")
    summary: str = Field(description="Brief 1-sentence summary")
    medicines: List[Medicine] = Field(default_factory=list)
    key_metrics: Dict[str, str] = Field(default_factory=dict)
    confidence_score: float = Field(default=0.5, description="0-1 score of extraction quality")

# --- LangGraph State ---

class AgentState(TypedDict):
    file_content: bytes
    mime_type: str
    raw_text: Optional[str]
    extracted_data: Optional[ExtractionResult]
    embedding: Optional[List[float]]
    history_context: Optional[str]
    current_time: str
    iterations: int
    errors: List[str]

# --- AI Service with LangGraph + Groq Fallback ---

class AIService:
    def __init__(self):
        self._use_groq = False
        self._init_llm()
        self.embeddings_model = GoogleGenerativeAIEmbeddings(
            model="models/embedding-001",
            google_api_key=settings.gemini_api_key
        )
        # Initialize Supabase for history lookups
        from supabase import create_client
        self.supabase = create_client(settings.supabase_url, settings.supabase_anon_key)
        self.workflow = self._build_graph()

    def _init_llm(self):
        """Initialize the LLM, with Groq fallback support."""
        if self._use_groq and settings.groq_api_key:
            from langchain_groq import ChatGroq
            logger.info("AI Service: Using Groq (llama-3.3-70b-versatile)")
            self.llm = ChatGroq(
                model="llama-3.3-70b-versatile",
                api_key=settings.groq_api_key,
                temperature=0
            )
        else:
            logger.info("AI Service: Using Gemini (gemini-2.0-flash)")
            self.llm = ChatGoogleGenerativeAI(
                model="gemini-2.0-flash",
                google_api_key=settings.gemini_api_key,
                temperature=0
            )

    def _build_graph(self):
        graph = StateGraph(AgentState)
        graph.add_node("vision_extraction", self.node_vision_extraction)
        graph.add_node("structured_parsing", self.node_structured_parsing)
        graph.add_node("generate_embedding", self.node_generate_embedding)
        graph.add_node("validation", self.node_validation)

        graph.set_entry_point("vision_extraction")
        graph.add_edge("vision_extraction", "structured_parsing")
        graph.add_edge("structured_parsing", "generate_embedding")
        graph.add_edge("generate_embedding", "validation")
        graph.add_conditional_edges("validation", self.should_continue, {
            "continue": "structured_parsing",
            "end": END
        })
        return graph.compile()

    # --- Graph Nodes ---

    async def node_vision_extraction(self, state: AgentState):
        """Extract raw text from medical document using vision AI."""
        logger.info("Node: Vision Extraction")
        import base64
        base64_image = base64.b64encode(state['file_content']).decode('utf-8')

        # Gemini supports vision; Groq needs text-only fallback
        if self._use_groq:
            # Groq doesn't support image input, return a placeholder
            return {"raw_text": "[Image uploaded — Groq cannot process images. Please retry when Gemini is available.]", "iterations": 0, "errors": []}

        message = HumanMessage(content=[
            {"type": "text", "text": "Describe every detail in this medical document, especially names, dates, and medications. Maintain accurate spelling and numbers."},
            {"type": "image_url", "image_url": {"url": f"data:{state['mime_type']};base64,{base64_image}"}}
        ])
        res = await self.llm.ainvoke([message])
        return {"raw_text": res.content, "iterations": 0, "errors": []}

    async def node_structured_parsing(self, state: AgentState):
        """Parse raw text into structured JSON."""
        logger.info("Node: Structured Parsing")
        structured_llm = self.llm.with_structured_output(ExtractionResult)

        prompt = f"""
        Current Date/Time: {state['current_time']}
        {state['history_context']}
        
        Extract medical data from the following text:
        {state['raw_text']}
        
        Ensure accuracy for medication names and dosages.
        If history is provided, mention how current results compare to previous trends in the summary.
        """
        result = await structured_llm.ainvoke(prompt)
        return {"extracted_data": result, "iterations": state.get('iterations', 0) + 1}

    async def node_generate_embedding(self, state: AgentState):
        """Generate vector embedding for semantic search."""
        logger.info("Node: Embedding Generation")
        try:
            text_to_embed = f"{state['extracted_data'].summary}\n{state['raw_text']}"
            embedding = await self.embeddings_model.aembed_query(text_to_embed)
            return {"embedding": embedding}
        except Exception as e:
            logger.error(f"Embedding generation failed: {e}")
            return {"embedding": None}

    async def node_validation(self, state: AgentState):
        """Validate extraction completeness."""
        data = state['extracted_data']
        errors = []
        if not data.type:
            errors.append("Document type missing")
        if data.type and data.type.lower() == "prescription" and not data.medicines:
            errors.append("Prescription detected but no medicines found")
        return {"errors": errors}

    def should_continue(self, state: AgentState):
        if state.get('errors') and state.get('iterations', 0) < 3:
            return "continue"
        return "end"

    async def _fetch_history(self, patient_id: str):
        """Fetch 3 months of medical history for context."""
        try:
            three_months_ago = (datetime.now() - timedelta(days=90)).strftime('%Y-%m-%d')
            res = self.supabase.from_('medical_records').select('type, extracted_text, record_date')\
                .eq('patient_id', patient_id)\
                .gte('record_date', three_months_ago)\
                .order('record_date', desc=True).limit(3).execute()

            if not res.data:
                return "No previous records found in the last 3 months."

            from .security_service import security_service
            history = "\n".join([
                f"- {r['record_date']}: {r['type']} - {security_service.decrypt_data(r['extracted_text'])}"
                for r in res.data if r.get('extracted_text')
            ])
            return f"Patient History (Past 3 Months):\n{history}"
        except Exception as e:
            logger.error(f"Error fetching history: {e}")
            return "Could not retrieve patient history."

    async def process_document(self, file_content: bytes, mime_type: str, patient_id: str = None):
        """Main entry point for document processing with automatic Groq fallback."""
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        history = await self._fetch_history(patient_id) if patient_id else "No patient history provided."

        initial_state = {
            "file_content": file_content,
            "mime_type": mime_type,
            "raw_text": None,
            "extracted_data": None,
            "embedding": None,
            "history_context": history,
            "current_time": current_time,
            "errors": [],
            "iterations": 0
        }

        # Try Gemini first, fall back to Groq on quota errors
        for attempt in range(2):
            try:
                final_state = await self.workflow.ainvoke(initial_state)

                if final_state["extracted_data"]:
                    data_dict = final_state["extracted_data"].model_dump()

                    from .security_service import security_service
                    raw_summary = data_dict.get('summary', '')
                    if raw_summary:
                        data_dict['summary'] = security_service.encrypt_data(raw_summary)
                    for med in data_dict.get('medicines', []):
                        if med.get('dosage'):
                            med['dosage'] = security_service.encrypt_data(med['dosage'])

                    return {
                        "structured_data": data_dict,
                        "embedding": final_state["embedding"]
                    }
                else:
                    raise Exception("AI failed to extract data: " + ", ".join(final_state.get("errors", [])))

            except Exception as e:
                error_msg = str(e)
                if ("429" in error_msg or "ResourceExhausted" in error_msg) and attempt == 0 and settings.groq_api_key:
                    logger.warning("Gemini quota hit during document processing, switching to Groq")
                    self._use_groq = True
                    self._init_llm()
                    self.workflow = self._build_graph()
                    continue
                raise


ai_service = AIService()
