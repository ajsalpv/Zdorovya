from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str
    gemini_api_key: str
    family_id: str
    encryption_key: str = "7jRz9qV8nW3mP6sL5kX2yH4vJ0bE1fG98MpsTYw_AhxGPHof=" 
    render_external_url: Optional[str] = None
    port: int = 8000

    model_config = {
        "env_file": ".env",
        "extra": "ignore"
    }

settings = Settings()
