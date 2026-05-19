import logging
import asyncio
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, UploadFile, File, Form, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
import uvicorn
import httpx

from .config import settings
from .services.ai_service import ai_service
from .services.copilot_service import copilot_agent

# --- Logging ---
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


# --- Keep-Alive Background Task ---
async def _keep_alive_ping():
    """Ping self every 4 minutes to prevent Render free-tier sleep."""
    base_url = os.environ.get("RENDER_EXTERNAL_URL", f"http://127.0.0.1:{settings.port}")
    url = f"{base_url}/api/ping"

    await asyncio.sleep(10)
    async with httpx.AsyncClient(timeout=10.0) as client:
        while True:
            try:
                resp = await client.get(url)
                logger.info(f"Keep-alive ping OK ({resp.status_code}) -> {url}")
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.warning(f"Keep-alive ping failed: {e}")
            await asyncio.sleep(240)

_keep_alive_task = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _keep_alive_task
    _keep_alive_task = asyncio.create_task(_keep_alive_ping())
    logger.info("🏥 Zdorovya Backend started — keep-alive active")
    yield
    if _keep_alive_task:
        _keep_alive_task.cancel()
    logger.info("🛑 Zdorovya Backend shutting down")


# --- App Setup ---
app = FastAPI(title="Zdorovya Backend", version="1.0.0", lifespan=lifespan)

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- Health Endpoints ---

@app.get("/", tags=["health"])
async def root():
    return {"message": "Zdorovya Backend is running", "version": "1.0.0"}

@app.get("/api/ping", tags=["health"])
async def ping_endpoint():
    return {"status": "ok", "message": "Zdorovya is awake!"}

@app.get("/health", tags=["health"])
async def health_check():
    return {"status": "healthy"}


# --- Medical Document Processing ---

@app.post("/api/v1/process-report", tags=["medical"])
@limiter.limit("30/day")
async def process_report(
    request: Request,
    file: UploadFile = File(...),
    patient_id: str = Form(None)
):
    """Process a medical document (image/PDF) and return structured AI extraction."""
    try:
        content = await file.read()
        mime_type = file.content_type

        result = await ai_service.process_document(content, mime_type, patient_id=patient_id)

        return {
            "success": True,
            "data": result["structured_data"],
            "embedding": result["embedding"]
        }
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Process report error: {error_msg}")
        if "429" in error_msg or "ResourceExhausted" in error_msg:
            raise HTTPException(status_code=429, detail="AI processing limit reached. Please try again later.")
        raise HTTPException(status_code=500, detail=error_msg)


# --- Copilot Chat ---

class ChatRequest(BaseModel):
    message: str
    session_id: str
    active_profile_id: str

@app.post("/api/v1/copilot/chat", tags=["copilot"])
@limiter.limit("100/day")
async def chat_with_copilot(req: ChatRequest, request: Request):
    """Conversational AI health assistant."""
    logger.info(f"Chat request from profile: {req.active_profile_id}, session: {req.session_id}")
    try:
        if not req.message or len(req.message.strip()) == 0:
            raise HTTPException(status_code=400, detail="Empty message")

        response = await copilot_agent.chat(req.message, req.session_id, req.active_profile_id)
        logger.info(f"Copilot responded for session {req.session_id}")
        return response

    except Exception as e:
        error_msg = str(e)
        logger.error(f"Chat error: {error_msg}", exc_info=True)
        if "429" in error_msg or "ResourceExhausted" in error_msg:
            raise HTTPException(status_code=429, detail="Health Copilot is busy. Please try again in 1 minute.")
        raise HTTPException(status_code=500, detail=error_msg)


if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=settings.port, reload=True)
