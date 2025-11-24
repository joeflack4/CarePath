"""Main FastAPI application for CarePath Chat API."""
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from service_chat.routers import health, triage
from service_chat.config import settings

# Global flag to track model readiness
_model_ready = False

# Configure logging with timestamps for all loggers (including uvicorn)
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    force=True  # Override uvicorn's default logging format
)
logger = logging.getLogger(__name__)

# Explicitly configure uvicorn's access logger with timestamp formatting
uvicorn_access_logger = logging.getLogger("uvicorn.access")
uvicorn_access_logger.setLevel(logging.INFO)
# Remove default handlers and add our own with timestamps
uvicorn_access_logger.handlers.clear()
handler = logging.StreamHandler()
handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
uvicorn_access_logger.addHandler(handler)
uvicorn_access_logger.propagate = False  # Don't duplicate to root logger


def is_model_ready() -> bool:
    """Check if the model is ready to serve requests."""
    return _model_ready


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    FastAPI lifespan handler for eager model loading.

    Loads the LLM model at startup so the pod isn't marked ready until
    the model is fully loaded. This prevents Kubernetes from routing
    traffic to pods that would block during model loading.
    """
    global _model_ready

    if settings.DEFAULT_LLM_MODE not in ("mock",):
        logger.info("Starting eager model loading (DEFAULT_LLM_MODE=%s)...", settings.DEFAULT_LLM_MODE)
        try:
            if settings.DEFAULT_LLM_MODE == "gguf":
                from service_chat.services.llm_client import _load_gguf_model_cached
                _load_gguf_model_cached()
            elif settings.DEFAULT_LLM_MODE in ("qwen", "Qwen3-4B-Thinking-2507"):
                from service_chat.services.llm_client import _load_model_cached
                _load_model_cached()
            elif settings.DEFAULT_LLM_MODE == "hf-qwen2.5":
                from service_chat.services.hf_client import warmup_hf_model
                warmup_hf_model()
            else:
                logger.warning("Unknown DEFAULT_LLM_MODE=%s - skipping model loading", settings.DEFAULT_LLM_MODE)
            logger.info("Model loaded successfully - pod is ready to serve requests")
        except Exception as e:
            logger.error("Failed to load model during startup: %s", e)
            raise
    else:
        logger.info("DEFAULT_LLM_MODE=%s - skipping eager model loading", settings.DEFAULT_LLM_MODE)

    _model_ready = True
    yield
    # Cleanup (if needed)
    logger.info("Shutting down CarePath Chat API")


# Create FastAPI app with lifespan handler
app = FastAPI(
    title="CarePath Chat API",
    version="0.1.0",
    description="AI-powered chat service for patient assistance with RAG and tracing",
    lifespan=lifespan
)

# Add CORS middleware for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health.router, tags=["health"])
app.include_router(triage.router, tags=["triage"])


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "service": "CarePath Chat API",
        "version": "0.1.0",
        "description": "AI-powered chat service for patient assistance",
        "default_llm_mode": settings.DEFAULT_LLM_MODE,
        "vector_mode": settings.VECTOR_MODE
    }
