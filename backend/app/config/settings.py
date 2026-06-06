from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    app_name: str = "Navigwiz AI Platform"
    app_version: str = "2.0.0"
    debug: bool = False

    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_service_key: str = ""

    jwt_secret: str = "navigwiz-jwt-secret-change-in-production"  # WARNING: change this in production!
    jwt_algorithm: str = "HS256"
    jwt_expiry_hours: int = 72

    chroma_db_path: str = "./data/chroma"
    faiss_index_path: str = "./data/faiss"
    memory_store_path: str = "./data/memory"

    redis_url: str = "redis://localhost:6379/0"
    celery_broker_url: str = "redis://localhost:6379/1"
    celery_result_backend: str = "redis://localhost:6379/2"

    openai_api_key: Optional[str] = None
    openai_model: str = "gpt-4o-mini"
    embedding_model: str = "all-MiniLM-L6-v2"
    whisper_model: str = "base"
    tts_model: str = "tts_models/en/ljspeech/tacotron2-DDC"

    searxng_url: str = "https://searx.be/search"
    brave_api_key: Optional[str] = None
    duckduckgo_enabled: bool = True

    cloudinary_cloud_name: Optional[str] = None
    cloudinary_api_key: Optional[str] = None
    cloudinary_api_secret: Optional[str] = None
    r2_endpoint: Optional[str] = None
    r2_access_key: Optional[str] = None
    r2_secret_key: Optional[str] = None
    r2_bucket: str = "navigwiz-media"

    sentry_dsn: Optional[str] = None
    prometheus_port: int = 9090

    cors_origins: list[str] = ["*"]
    max_upload_size_mb: int = 100
    rate_limit_per_minute: int = 60

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
