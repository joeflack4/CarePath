"""Chat log endpoints (optional for debugging)."""
from typing import Optional
from fastapi import APIRouter, HTTPException, Query
from motor.motor_asyncio import AsyncIOMotorDatabase

from service_db_api.db.mongo import get_database

router = APIRouter()


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
