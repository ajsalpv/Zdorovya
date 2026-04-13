from fastapi import FastAPI, Depends, HTTPException, Header, UploadFile, File
from supabase import create_client, Client
from .config import settings
from .services.ai_service import ai_service
from .services.copilot_service import copilot_agent
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="Zdorovya Backend")

# Supabase client initialization
supabase: Client = create_client(settings.supabase_url, settings.supabase_anon_key)

@app.get("/")
async def root():
    return {"message": "Zdorovya Backend is running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

async def verify_token(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid token")
    
    token = authorization.split(" ")[1]
    try:
        # Validate token with Supabase
        user = supabase.auth.get_user(token)
        return user
    except Exception as e:
        raise HTTPException(status_code=401, detail=str(e))

@app.post("/api/v1/process-report")
async def process_report(
    file: UploadFile = File(...),
    # user_profile = Depends(verify_token) # Enable this when auth is fully linked
):
    """
    Endpoint to process a medical document (Image/PDF).
    Returns structured JSON data extracted by AI.
    """
    try:
        content = await file.read()
        mime_type = file.content_type
        
        # Call AI service
        extracted_data = await ai_service.process_document(content, mime_type)
        
        return {
            "success": True,
            "data": extracted_data
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class ChatRequest(BaseModel):
    message: str
    session_id: str

@app.post("/api/v1/copilot/chat")
async def chat_with_copilot(req: ChatRequest):
    """
    Conversational AI interface for family health.
    """
    try:
        response = await copilot_agent.chat(req.message, req.session_id)
        return response
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=settings.port, reload=True)
