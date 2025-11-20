"""Document model based on data-snippets.md."""
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field
from bson import ObjectId


class DocumentMetadata(BaseModel):
    """Document metadata."""
    author_provider_id: Optional[str] = None
    created_at: str
    encounter_id: Optional[str] = None


class Document(BaseModel):
    """Document model."""
    id: Optional[str] = Field(alias="_id", default=None)
    doc_id: str
    patient_mrn: str
    source_type: str
    title: str
    text: str
    tags: List[str] = []
    metadata: Optional[DocumentMetadata] = None

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}
