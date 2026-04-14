import json
import logging
from typing import List, Optional, Dict, Any, TypedDict
from pydantic import BaseModel, Field
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import HumanMessage, BaseMessage
from langgraph.graph import StateGraph, END
from app.config import settings

logger = logging.getLogger(__name__)

# --- Structured Output Schema ---

class Medicine(BaseModel):
    name: str = Field(description="Name of the medicine")
    dosage: Optional[str] = Field(description="Dosage, e.g., 500mg")
    frequency: Optional[str] = Field(description="Frequency, e.g., Twice a day")
    duration: Optional[str] = Field(description="Duration of treatment")
    quantity: Optional[str] = Field(description="Quantity purchased (for receipts)")
    price: Optional[str] = Field(description="Price (for receipts)")

class ExtractionResult(BaseModel):
    type: str = Field(description="ECG, Blood Test, Prescription, Receipt, etc.")
    patient_name: Optional[str] = Field(description="Name of the person")
    date: Optional[str] = Field(description="Document date in YYYY-MM-DD")
    doctor_name: Optional[str] = Field(description="Doctor or Hospital name")
    summary: str = Field(description="Brief 1-sentence summary")
    medicines: List[Medicine] = Field(default_factory=list)
    key_metrics: Dict[str, str] = Field(default_factory=dict)
    confidence_score: float = Field(description="0-1 score of extraction quality")

# --- LangGraph State ---

class AgentState(TypedDict):
    file_content: bytes
    mime_type: str
    raw_text: Optional[str]
    extracted_data: Optional[ExtractionResult]
    errors: List[str]
    iterations: int

# --- AI Service with LangGraph ---

class AIService:
    def __init__(self):
        self.llm = ChatGoogleGenerativeAI(
            model="gemini-2.0-flash",
            google_api_key=settings.gemini_api_key,
            temperature=0
        )
        self.workflow = self._build_graph()

    def _build_graph(self):
        graph = StateGraph(AgentState)
        
        # Add Nodes
        graph.add_node("vision_extraction", self.node_vision_extraction)
        graph.add_node("structured_parsing", self.node_structured_parsing)
        graph.add_node("validation", self.node_validation)

        # Build Flow
        graph.set_entry_point("vision_extraction")
        graph.add_edge("vision_extraction", "structured_parsing")
        graph.add_edge("structured_parsing", "validation")
        
        # Conditional Edge for Validation
        graph.add_conditional_edges(
            "validation",
            self.should_continue,
            {
                "continue": "structured_parsing",
                "end": END
            }
        )
        
        return graph.compile()

    # --- Nodes ---

    async def node_vision_extraction(self, state: AgentState):
        """Extract raw text and visual context using Gemini Vision."""
        logger.info("Starting Vision Extraction Node")
        
        # Prepare multimodal content for LangChain/Gemini
        import base64
        base64_image = base64.b64encode(state['file_content']).decode('utf-8')
        
        message = HumanMessage(content=[
            {"type": "text", "text": "Describe every detail in this medical document, especially names, dates, and medications. Maintain accurate spelling and numbers."},
            {
                "type": "image_url",
                "image_url": {"url": f"data:{state['mime_type']};base64,{base64_image}"}
            }
        ])
        
        res = await self.llm.ainvoke([message])
        return {"raw_text": res.content, "iterations": 0, "errors": []}

    async def node_structured_parsing(self, state: AgentState):
        """Parse raw text into structured JSON schema."""
        logger.info("Starting Structured Parsing Node")
        
        structured_llm = self.llm.with_structured_output(ExtractionResult)
        
        prompt = f"""
        Extract medical data from the following text:
        {state['raw_text']}
        
        Ensure accuracy for medication names and dosages.
        """
        
        result = await structured_llm.ainvoke(prompt)
        return {"extracted_data": result, "iterations": state['iterations'] + 1}

    async def node_validation(self, state: AgentState):
        """Validate if the extraction is complete and logical."""
        data = state['extracted_data']
        errors = []
        
        if not data.type:
            errors.append("Document type missing")
        if data.type.lower() == "prescription" and not data.medicines:
            errors.append("Prescription detected but no medicines found")
            
        return {"errors": errors}

    def should_continue(self, state: AgentState):
        if state['errors'] and state['iterations'] < 3:
            return "continue"
        return "end"

    async def process_document(self, file_content: bytes, mime_type: str):
        """Entry point for documentation processing."""
        initial_state = {
            "file_content": file_content,
            "mime_type": mime_type,
            "raw_text": None,
            "extracted_data": None,
            "errors": [],
            "iterations": 0
        }
        
        # Execute Graph
        # In actual execution, we'd pass the file_content correctly to the vision node
        # For now, we'll wrap the logic to handle the multimodal call properly
        
        # SIMPLIFIED FOR PRODUCTION RELIABILITY
        final_state = await self.workflow.ainvoke(initial_state)
        
        if final_state["extracted_data"]:
            return final_state["extracted_data"].model_dump()
        else:
            raise Exception("AI failed to extract data: " + ", ".join(final_state["errors"]))

ai_service = AIService()
