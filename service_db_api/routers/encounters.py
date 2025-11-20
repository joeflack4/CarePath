"""Encounter endpoints."""
from typing import Optional
from fastapi import APIRouter, HTTPException, Query
from motor.motor_asyncio import AsyncIOMotorDatabase

from service_db_api.db.mongo import get_database

router = APIRouter()


@router.get("/encounters")
async def list_encounters(
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100),
    patient_mrn: Optional[str] = None
):
    """List encounters with optional filtering by patient MRN."""
    db: AsyncIOMotorDatabase = await get_database()

    query = {}
    if patient_mrn:
        query["patient_mrn"] = patient_mrn

    cursor = db.encounters.find(query).skip(skip).limit(limit)
    encounters = await cursor.to_list(length=limit)

    # Convert ObjectId to string
    for encounter in encounters:
        if "_id" in encounter:
            encounter["_id"] = str(encounter["_id"])

    total = await db.encounters.count_documents(query)

    return {
        "items": encounters,
        "total": total,
        "skip": skip,
        "limit": limit
    }


@router.get("/encounters/{encounter_id}")
async def get_encounter(encounter_id: str):
    """Get a single encounter by encounter_id."""
    db: AsyncIOMotorDatabase = await get_database()

    encounter = await db.encounters.find_one({"encounter_id": encounter_id})

    if not encounter:
        raise HTTPException(
            status_code=404,
            detail=f"Encounter with ID {encounter_id} not found"
        )

    # Convert ObjectId to string
    if "_id" in encounter:
        encounter["_id"] = str(encounter["_id"])

    return encounter


@router.get("/patients/{mrn}/encounters")
async def list_patient_encounters(mrn: str):
    """Get all encounters for a specific patient, sorted by start date descending."""
    db: AsyncIOMotorDatabase = await get_database()

    cursor = db.encounters.find({"patient_mrn": mrn}).sort("start", -1)
    encounters = await cursor.to_list(length=None)

    # Convert ObjectId to string
    for encounter in encounters:
        if "_id" in encounter:
            encounter["_id"] = str(encounter["_id"])

    return {
        "patient_mrn": mrn,
        "encounters": encounters,
        "count": len(encounters)
    }
