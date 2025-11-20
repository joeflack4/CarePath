"""Audit log model based on data-snippets.md."""
from typing import Optional
from pydantic import BaseModel, Field
from bson import ObjectId


class AuditLog(BaseModel):
    """Audit log model (optional)."""
    id: Optional[str] = Field(alias="_id", default=None)
    event_id: str
    event_type: str
    actor_type: str
    actor_id: str
    patient_mrn: Optional[str] = None
    model_name: Optional[str] = None
    request_id: str
    created_at: str
    input_summary: Optional[str] = None
    output_summary: Optional[str] = None
    latency_ms: int
    status: str

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}
