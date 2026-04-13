from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str
    gemini_api_key: str
    port: int = 8000

    model_config = {
        "env_file": ".env",
        "extra": "ignore"
    }

settings = Settings()
