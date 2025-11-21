"""Chat log endpoints for storing and retrieving conversation logs."""
import uuid
from datetime import datetime
from typing import Optional, List
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field
from motor.motor_asyncio import AsyncIOMotorDatabase

from service_db_api.db.mongo import get_database

router = APIRouter()


# --- Pydantic Models for Chat Log Creation ---

class MessageCreate(BaseModel):
    """A single message in the conversation."""
    role: str  # "user" or "assistant"
    content: str
    timestamp: Optional[str] = None  # ISO format, auto-set if not provided
    model_name: Optional[str] = None  # For assistant messages
    latency_ms: Optional[float] = None  # For assistant messages


class RetrievalEventCreate(BaseModel):
    """A retrieval event during the conversation."""
    step_id: int
    query_type: str  # "db_query", "fts", "vector"
    query: str  # Description or actual query
    endpoint: Optional[str] = None  # e.g., "/patients/{mrn}/summary"
    latency_ms: Optional[float] = None
    results: Optional[List[dict]] = None  # For FTS/vector results
    record_count: Optional[int] = None  # For db_query results


class ChatLogCreate(BaseModel):
    """Request body for creating a new chat log."""
    patient_mrn: str
    channel: str = "api"  # "api", "web", etc.
    messages: List[MessageCreate]
    retrieval_events: Optional[List[RetrievalEventCreate]] = None
    trace_id: Optional[str] = None
    conversation_id: Optional[str] = None  # Auto-generated if not provided


class ChatLogResponse(BaseModel):
    """Response after creating a chat log."""
    id: str = Field(alias="_id")
    conversation_id: str
    patient_mrn: str
    channel: str
    started_at: str
    ended_at: str
    messages: List[dict]
    retrieval_events: Optional[List[dict]] = None
    trace_id: Optional[str] = None

    class Config:
        populate_by_name = True


def _generate_conversation_id(patient_mrn: str) -> str:
    """Generate a unique conversation ID."""
    date_str = datetime.utcnow().strftime("%Y-%m-%d")
    short_uuid = uuid.uuid4().hex[:8]
    return f"CONV-{date_str}-{patient_mrn}-{short_uuid}"


@router.post("/chat-logs", response_model=ChatLogResponse, status_code=201)
async def create_chat_log(chat_log: ChatLogCreate):
    """
    Create a new chat log entry.

    This endpoint stores a conversation (single query/response) with metadata
    including messages and retrieval events.
    """
    db: AsyncIOMotorDatabase = await get_database()

    # Validate messages are not empty
    if not chat_log.messages:
        raise HTTPException(
            status_code=400,
            detail="Messages array cannot be empty"
        )

    # Generate conversation_id if not provided
    conversation_id = chat_log.conversation_id or _generate_conversation_id(chat_log.patient_mrn)

    # Get current timestamp
    now = datetime.utcnow().isoformat() + "Z"

    # Process messages - add timestamps if missing
    messages = []
    for msg in chat_log.messages:
        msg_dict = msg.model_dump(exclude_none=True)
        if "timestamp" not in msg_dict:
            msg_dict["timestamp"] = now
        messages.append(msg_dict)

    # Process retrieval events
    retrieval_events = None
    if chat_log.retrieval_events:
        retrieval_events = [evt.model_dump(exclude_none=True) for evt in chat_log.retrieval_events]

    # Build the document
    chat_log_doc = {
        "conversation_id": conversation_id,
        "patient_mrn": chat_log.patient_mrn,
        "channel": chat_log.channel,
        "started_at": now,
        "ended_at": now,
        "messages": messages,
        "retrieval_events": retrieval_events,
        "trace_id": chat_log.trace_id
    }

    # Insert into MongoDB
    result = await db.chat_logs.insert_one(chat_log_doc)

    # Prepare response
    chat_log_doc["_id"] = str(result.inserted_id)

    return ChatLogResponse(**chat_log_doc)


@router.get("/chat-logs")
async def list_chat_logs(
    patient_mrn: Optional[str] = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100)
):
    """List chat logs with optional filtering by patient MRN."""
    db: AsyncIOMotorDatabase = await get_database()

    query = {}
    if patient_mrn:
        query["patient_mrn"] = patient_mrn

    cursor = db.chat_logs.find(query).skip(skip).limit(limit)
    chat_logs = await cursor.to_list(length=limit)

    # Convert ObjectId to string
    for log in chat_logs:
        if "_id" in log:
            log["_id"] = str(log["_id"])

    total = await db.chat_logs.count_documents(query)

    return {
        "items": chat_logs,
        "total": total,
        "skip": skip,
        "limit": limit
    }


@router.get("/chat-logs/{conversation_id}")
async def get_chat_log(conversation_id: str):
    """Get a single chat log by conversation_id."""
    db: AsyncIOMotorDatabase = await get_database()

    chat_log = await db.chat_logs.find_one({"conversation_id": conversation_id})

    if not chat_log:
        raise HTTPException(
            status_code=404,
            detail=f"Chat log with conversation ID {conversation_id} not found"
        )

    # Convert ObjectId to string
    if "_id" in chat_log:
        chat_log["_id"] = str(chat_log["_id"])

    return chat_log
