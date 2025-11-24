"""Configuration for service_chat using pydantic-settings."""
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # API settings
    CHAT_API_PORT: int = 8002
    DB_API_BASE_URL: str = "http://localhost:8001"

    # LLM settings
    DEFAULT_LLM_MODE: str = "hf-qwen2.5"  # "mock", "gguf", "qwen", "Qwen3-4B-Thinking-2507", or "hf-qwen2.5"
    LLM_BACKEND: str = "auto"  # "auto", "transformers", or "gguf" (auto infers from DEFAULT_LLM_MODE)
    MODEL_CACHE_DIR: str = "./models"  # Directory for downloaded models

    # GGUF model settings (for LLM_BACKEND=gguf or LLM_MODE=gguf)
    GGUF_MODEL_REPO: str = "Qwen/Qwen2.5-1.5B-Instruct-GGUF"  # HuggingFace repo
    GGUF_MODEL_FILE: str = "qwen2.5-1.5b-instruct-q4_k_m.gguf"  # Specific GGUF file
    GGUF_N_CTX: int = 4096  # Context window size
    GGUF_N_THREADS: int = 4  # Number of CPU threads
    GGUF_MAX_TOKENS: int = 256  # Max tokens to generate

    # Hugging Face Inference API settings (for DEFAULT_LLM_MODE=hf-qwen2.5)
    HF_API_TOKEN: str = ""  # HuggingFace API token
    HF_QWEN_MODEL_ID: str = "Qwen/Qwen2.5-7B-Instruct:together"  # Router with Together AI provider
    HF_TIMEOUT_SECONDS: int = 30  # Request timeout
    HF_MAX_NEW_TOKENS: int = 256  # Max tokens to generate
    HF_TEMPERATURE: float = 0.7  # Sampling temperature

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
