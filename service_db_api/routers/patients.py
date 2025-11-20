"""Patient endpoints."""
from typing import Optional
from fastapi import APIRouter, HTTPException, Query
from motor.motor_asyncio import AsyncIOMotorDatabase

from service_db_api.db.mongo import get_database

router = APIRouter()


@router.get("/patients")
async def list_patients(
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100)
):
    """List all patients with pagination."""
    db: AsyncIOMotorDatabase = await get_database()

    cursor = db.patients.find().skip(skip).limit(limit)
    patients = await cursor.to_list(length=limit)

    # Convert ObjectId to string for JSON serialization
    for patient in patients:
        if "_id" in patient:
            patient["_id"] = str(patient["_id"])

    total = await db.patients.count_documents({})

    return {
        "items": patients,
        "total": total,
        "skip": skip,
        "limit": limit
    }


@router.get("/patients/{mrn}")
async def get_patient(mrn: str):
    """Get a single patient by MRN."""
    db: AsyncIOMotorDatabase = await get_database()

    patient = await db.patients.find_one({"mrn": mrn})

    if not patient:
        raise HTTPException(status_code=404, detail=f"Patient with MRN {mrn} not found")

    # Convert ObjectId to string
    if "_id" in patient:
        patient["_id"] = str(patient["_id"])

    return patient


@router.get("/patients/{mrn}/summary")
async def get_patient_summary(mrn: str):
    """
    Get comprehensive patient summary including:
    - Patient base record
    - Recent encounters
    - Recent claims
    - Key documents (care plans, etc.)

    This summary is designed to be used by service_chat for RAG context.
    """
    db: AsyncIOMotorDatabase = await get_database()

    # Get patient base record
    patient = await db.patients.find_one({"mrn": mrn})
    if not patient:
        raise HTTPException(status_code=404, detail=f"Patient with MRN {mrn} not found")

    # Convert ObjectId to string
    if "_id" in patient:
        patient["_id"] = str(patient["_id"])

    # Get recent encounters (last 10, sorted by start date descending)
    encounters_cursor = db.encounters.find({"patient_mrn": mrn}).sort("start", -1).limit(10)
    encounters = await encounters_cursor.to_list(length=10)
    for enc in encounters:
        if "_id" in enc:
            enc["_id"] = str(enc["_id"])

    # Get recent claims (last 10, sorted by service date descending)
    claims_cursor = db.claims.find({"patient_mrn": mrn}).sort("service_date", -1).limit(10)
    claims = await claims_cursor.to_list(length=10)
    for claim in claims:
        if "_id" in claim:
            claim["_id"] = str(claim["_id"])

    # Get key documents (care plans, visit notes, etc.)
    documents_cursor = db.documents.find({"patient_mrn": mrn}).limit(20)
    documents = await documents_cursor.to_list(length=20)
    for doc in documents:
        if "_id" in doc:
            doc["_id"] = str(doc["_id"])

    # Build comprehensive summary
    summary = {
        "patient": patient,
        "recent_encounters": encounters,
        "recent_claims": claims,
        "documents": documents,
        "summary_metadata": {
            "mrn": mrn,
            "encounter_count": len(encounters),
            "claim_count": len(claims),
            "document_count": len(documents)
        }
    }

    return summary
