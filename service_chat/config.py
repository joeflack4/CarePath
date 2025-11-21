"""Configuration for service_chat using pydantic-settings."""
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # API settings
    CHAT_API_PORT: int = 8002
    DB_API_BASE_URL: str = "http://localhost:8001"

    # LLM settings
    LLM_MODE: str = "mock"  # "mock", "qwen", or "Qwen3-4B-Thinking-2507"

    # Vector DB settings
    VECTOR_MODE: str = "mock"  # "mock" or "pinecone"

    # Pinecone settings (for future use)
    PINECONE_API_KEY: str = ""
    PINECONE_ENVIRONMENT: str = ""
    PINECONE_INDEX_NAME: str = "carepath-documents"

    # Logging
    LOG_LEVEL: str = "INFO"

    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"  # Ignore extra env vars from shared .env file


# Global settings instance
settings = Settings()
