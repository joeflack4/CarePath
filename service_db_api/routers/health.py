"""Health check endpoints."""
from fastapi import APIRouter

from service_db_api.db.mongo import mongo

router = APIRouter()


@router.get("/health")
async def health():
    """Health check endpoint."""
    return {
        "status": "ok",
        "service": "db-api",
        "version": "0.1.0"
    }


@router.get("/health/db")
async def health_db():
    """Database connectivity health check."""
    ping_result = await mongo.ping()
    return {
        "status": "ok" if ping_result["success"] else "error",
        "service": "db-api",
        "database": "mongodb",
        "connected": ping_result["success"],
        "latency_ms": ping_result.get("latency_ms", 0),
        "error": ping_result.get("error")
    }
