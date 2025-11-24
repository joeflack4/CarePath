"""Health check endpoints for service_chat."""
from fastapi import APIRouter
from fastapi.responses import JSONResponse

router = APIRouter()


@router.get("/health")
async def health():
    """
    Liveness probe endpoint.

    Always returns 200 OK if the server is running.
    Used by Kubernetes liveness probe to check if the container is alive.
    """
    return {
        "status": "ok",
        "service": "chat-api",
        "version": "0.1.0"
    }


@router.get("/ready")
async def ready():
    """
    Readiness probe endpoint.

    Returns 200 OK only when the model is fully loaded and ready to serve requests.
    Returns 503 Service Unavailable while the model is still loading.
    Used by Kubernetes readiness probe to control traffic routing.
    """
    from service_chat.main import is_model_ready

    if is_model_ready():
        return {
            "status": "ready",
            "service": "chat-api",
            "version": "0.1.0"
        }
    else:
        return JSONResponse(
            status_code=503,
            content={
                "status": "loading",
                "service": "chat-api",
                "version": "0.1.0",
                "message": "Model is still loading, please wait"
            }
        )
