"""Patient model based on data-snippets.md."""
from typing import Optional, List
from pydantic import BaseModel, Field
from bson import ObjectId


class PyObjectId(ObjectId):
    """Custom ObjectId type for Pydantic."""
    @classmethod
    def __get_validators__(cls):
        yield cls.validate

    @classmethod
    def validate(cls, v):
        if not ObjectId.is_valid(v):
            raise ValueError("Invalid ObjectId")
        return ObjectId(v)


class Name(BaseModel):
    """Patient name."""
    first: str
    last: str


class Address(BaseModel):
    """Patient address."""
    line1: str
    city: str
    state: str
    zip: str


class Condition(BaseModel):
    """Medical condition."""
    code: str
    system: str
    display: str
    onset_date: Optional[str] = None


class Medication(BaseModel):
    """Medication."""
    drug_code: str
    name: str
    start_date: str
    end_date: Optional[str] = None
    sig: str


class Allergy(BaseModel):
    """Allergy."""
    substance: str
    reaction: str
    severity: str


class Patient(BaseModel):
    """Patient model."""
    id: Optional[str] = Field(alias="_id", default=None)
    mrn: str
    name: Name
    dob: str
    sex: str
    address: Address
    conditions: List[Condition] = []
    medications: List[Medication] = []
    allergies: List[Allergy] = []
    primary_care_provider_id: Optional[str] = None
    risk_score: Optional[float] = None

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}
