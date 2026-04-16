from fastapi import FastAPI, Depends, HTTPException, Header, UploadFile, File, Form
from functools import lru_cache
from datetime import datetime
from supabase import create_client, Client
from .config import settings
from .services.ai_service import ai_service
from .services.copilot_service import copilot_agent
import logging
from pydantic import BaseModel
import uvicorn
import asyncio
import httpx
import os
from contextlib import asynccontextmanager
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from fastapi import Request

async def _keep_alive_ping():
    """Background task to ping the server every 4 minutes to prevent Render sleep."""
    base_url = os.environ.get("RENDER_EXTERNAL_URL", f"http://127.0.0.1:{settings.port}")
    url = f"{base_url}/api/ping"
    
    await asyncio.sleep(10)  # Wait for startup
    async with httpx.AsyncClient(timeout=10.0) as client:
        while True:
            try:
                resp = await client.get(url)
                logger.info(f"Keep-alive ping OK ({resp.status_code}) -> {url}")
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.warning(f"Keep-alive ping failed: {e}")
            await asyncio.sleep(240)  # 4 minutes

_keep_alive_task = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global _keep_alive_task
    # Startup: Start keep-alive pinger
    _keep_alive_task = asyncio.create_task(_keep_alive_ping())
    logger.info("🏥 Zdorovya Backend started — keep-alive active (4 min interval)")
    yield
    # Shutdown: Stop task
    if _keep_alive_task:
        _keep_alive_task.cancel()
    logger.info("🛑 Zdorovya Backend shutting down")

app = FastAPI(title="Zdorovya Backend", lifespan=lifespan)
logger = logging.getLogger(__name__)

# Security & Rate Limiting
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # In production, replace with your specific app domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Supabase client initialization
supabase: Client = create_client(settings.supabase_url, settings.supabase_anon_key)

@app.get("/")
async def root():
    return {"message": "Zdorovya Backend is running"}

@app.get("/api/ping", tags=["health"])
async def ping_endpoint():
    """Lightweight endpoint used by keep-alive pinger and GitHub Action."""
    return {"status": "ok", "message": "Zdorovya is awake!"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

@lru_cache(maxsize=128)
def _get_cached_user(token: str):
    """Internal cache to avoid hammering Supabase auth endpoints."""
    return supabase.auth.get_user(token)

async def verify_token(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid token")
    
    token = authorization.split(" ")[1]
    try:
        user = _get_cached_user(token)
        return user
    except Exception as e:
        logger.error(f"Token verification failed: {e}")
        raise HTTPException(status_code=401, detail=str(e))

@app.post("/api/v1/process-report")
@limiter.limit("30/day")
async def process_report(
    request: Request,
    file: UploadFile = File(...),
    patient_id: str = Form(None),
    user_profile = Depends(verify_token)
):
    """
    Endpoint to process a medical document (Image/PDF).
    Returns structured JSON data extracted by AI.
    """
    try:
        content = await file.read()
        mime_type = file.content_type
        
        # Call AI service with historical context
        extracted_data = await ai_service.process_document(content, mime_type, patient_id=patient_id)
        
        return {
            "success": True,
            "data": extracted_data
        }
    except Exception as e:
        error_msg = str(e)
        if "429" in error_msg or "ResourceExhausted" in error_msg:
             raise HTTPException(
                status_code=429, 
                detail="Daily AI processing limit reached. Please try again in a few minutes or tomorrow."
            )
        raise HTTPException(status_code=500, detail=error_msg)

class ChatRequest(BaseModel):
    message: str
    session_id: str

@app.post("/api/v1/copilot/chat")
@limiter.limit("100/day")
async def chat_with_copilot(req: ChatRequest, request: Request, user_profile = Depends(verify_token)):
    """
    Conversational AI interface for family health.
    """
    try:
        response = await copilot_agent.chat(req.message, req.session_id)
        return response
    except Exception as e:
        logger.error(f"Chat error: {e}")
        error_msg = str(e)
        if "429" in error_msg or "ResourceExhausted" in error_msg:
             raise HTTPException(
                status_code=429, 
                detail="Health Copilot is busy. Please try again in 1 minute."
            )
        raise HTTPException(status_code=500, detail=error_msg)

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=settings.port, reload=True)
