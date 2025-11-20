"""Main FastAPI application for CarePath Chat API."""
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from service_chat.routers import health, triage
from service_chat.config import settings

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# Create FastAPI app
app = FastAPI(
    title="CarePath Chat API",
    version="0.1.0",
    description="AI-powered chat service for patient assistance with RAG and tracing"
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
        "llm_mode": settings.LLM_MODE,
        "vector_mode": settings.VECTOR_MODE
    }
