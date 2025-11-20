"""Encounter model based on data-snippets.md."""
from typing import Optional, List
from pydantic import BaseModel, Field
from bson import ObjectId


class Diagnosis(BaseModel):
    """Diagnosis."""
    code: str
    system: str
    display: str


class Vitals(BaseModel):
    """Vital signs."""
    bp_systolic: Optional[int] = None
    bp_diastolic: Optional[int] = None
    heart_rate: Optional[int] = None
    weight_kg: Optional[float] = None


class Lab(BaseModel):
    """Lab result."""
    name: str
    loinc: str
    value: float
    unit: str
    collected_at: str


class Encounter(BaseModel):
    """Encounter model."""
    id: Optional[str] = Field(alias="_id", default=None)
    patient_mrn: str
    encounter_id: str
    type: str
    location: str
    start: str
    end: str
    diagnoses: List[Diagnosis] = []
    vitals: Optional[Vitals] = None
    labs: List[Lab] = []
    notes: Optional[str] = None

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}
