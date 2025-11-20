"""Provider model based on data-snippets.md."""
from typing import Optional
from pydantic import BaseModel, Field
from bson import ObjectId


class ProviderName(BaseModel):
    """Provider name."""
    first: str
    last: str


class Provider(BaseModel):
    """Provider model (optional)."""
    id: Optional[str] = Field(alias="_id", default=None)
    provider_id: str
    npi: str
    name: ProviderName
    specialty: str
    location: str

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}
