"""Health check endpoint for service_chat."""
from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health():
    """Health check endpoint."""
    return {
        "status": "ok",
        "service": "chat-api",
        "version": "0.1.0"
    }
