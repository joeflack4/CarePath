"""Claim endpoints."""
from typing import Optional
from fastapi import APIRouter, HTTPException, Query
from motor.motor_asyncio import AsyncIOMotorDatabase

from service_db_api.db.mongo import get_database

router = APIRouter()


@router.get("/claims")
async def list_claims(
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100),
    patient_mrn: Optional[str] = None
):
    """List claims with optional filtering by patient MRN."""
    db: AsyncIOMotorDatabase = await get_database()

    query = {}
    if patient_mrn:
        query["patient_mrn"] = patient_mrn

    cursor = db.claims.find(query).skip(skip).limit(limit)
    claims = await cursor.to_list(length=limit)

    # Convert ObjectId to string
    for claim in claims:
        if "_id" in claim:
            claim["_id"] = str(claim["_id"])

    total = await db.claims.count_documents(query)

    return {
        "items": claims,
        "total": total,
        "skip": skip,
        "limit": limit
    }


@router.get("/claims/{claim_id}")
async def get_claim(claim_id: str):
    """Get a single claim by claim_id."""
    db: AsyncIOMotorDatabase = await get_database()

    claim = await db.claims.find_one({"claim_id": claim_id})

    if not claim:
        raise HTTPException(
            status_code=404,
            detail=f"Claim with ID {claim_id} not found"
        )

    # Convert ObjectId to string
    if "_id" in claim:
        claim["_id"] = str(claim["_id"])

    return claim
