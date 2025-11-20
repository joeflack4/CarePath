"""Claim model based on data-snippets.md."""
from typing import Optional, List
from pydantic import BaseModel, Field
from bson import ObjectId


class Claim(BaseModel):
    """Claim model."""
    id: Optional[str] = Field(alias="_id", default=None)
    claim_id: str
    patient_mrn: str
    payer: str
    service_date: str
    cpt_codes: List[str] = []
    icd10_codes: List[str] = []
    billed_amount: float
    allowed_amount: float
    patient_responsibility: float
    status: str

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}
