"""Chat log model based on data-snippets.md."""
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field
from bson import ObjectId


class Message(BaseModel):
    """Chat message."""
    role: str
    content: str
    timestamp: str
    model_name: Optional[str] = None
    latency_ms: Optional[int] = None


class RetrievalResult(BaseModel):
    """Single retrieval result."""
    doc_id: str
    score: float


class RetrievalEvent(BaseModel):
    """Retrieval event for RAG."""
    step_id: int
    query: str
    top_k: int
    retrieval_latency_ms: int
    total_documents_searched: int
    results: List[RetrievalResult] = []


class ChatLog(BaseModel):
    """Chat log model."""
    id: Optional[str] = Field(alias="_id", default=None)
    conversation_id: str
    patient_mrn: str
    channel: str
    started_at: str
    ended_at: Optional[str] = None
    messages: List[Message] = []
    retrieval_events: List[RetrievalEvent] = []

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}
