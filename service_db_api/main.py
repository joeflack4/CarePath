"""Main FastAPI application for CarePath DB API."""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from service_db_api.db.mongo import mongo
from service_db_api.routers import (
    health,
    patients,
    encounters,
    claims,
    documents,
    chat_logs
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle."""
    # Startup
    await mongo.connect()
    try:
        ping_result = await mongo.ping()
        if ping_result["success"]:
            print(f" Connected to MongoDB (latency: {ping_result['latency_ms']}ms)")
        else:
            print(f" Failed to connect to MongoDB: {ping_result.get('error')}")
    except Exception as e:
        print(f" Error connecting to MongoDB: {e}")

    yield

    # Shutdown
    await mongo.close()
    print(" MongoDB connection closed")


# Create FastAPI app
app = FastAPI(
    title="CarePath DB API",
    version="0.1.0",
    description="MongoDB-backed data service for CarePath AI",
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
app.include_router(patients.router, tags=["patients"])
app.include_router(encounters.router, tags=["encounters"])
app.include_router(claims.router, tags=["claims"])
app.include_router(documents.router, tags=["documents"])
app.include_router(chat_logs.router, tags=["chat-logs"])


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "service": "CarePath DB API",
        "version": "0.1.0",
        "description": "MongoDB-backed data service for healthcare data"
    }
