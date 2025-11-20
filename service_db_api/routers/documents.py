"""Document endpoints."""
from typing import Optional
from fastapi import APIRouter, HTTPException, Query
from motor.motor_asyncio import AsyncIOMotorDatabase

from service_db_api.db.mongo import get_database

router = APIRouter()


@router.get("/documents")
async def list_documents(
    patient_mrn: Optional[str] = None,
    source_type: Optional[str] = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100)
):
    """List documents with optional filtering by patient MRN and source type."""
    db: AsyncIOMotorDatabase = await get_database()

    query = {}
    if patient_mrn:
        query["patient_mrn"] = patient_mrn
    if source_type:
        query["source_type"] = source_type

    cursor = db.documents.find(query).skip(skip).limit(limit)
    documents = await cursor.to_list(length=limit)

    # Convert ObjectId to string
    for doc in documents:
        if "_id" in doc:
            doc["_id"] = str(doc["_id"])

    total = await db.documents.count_documents(query)

    return {
        "items": documents,
        "total": total,
        "skip": skip,
        "limit": limit
    }


@router.get("/documents/{doc_id}")
async def get_document(doc_id: str):
    """Get a single document by doc_id."""
    db: AsyncIOMotorDatabase = await get_database()

    document = await db.documents.find_one({"doc_id": doc_id})

    if not document:
        raise HTTPException(
            status_code=404,
            detail=f"Document with ID {doc_id} not found"
        )

    # Convert ObjectId to string
    if "_id" in document:
        document["_id"] = str(document["_id"])

    return document


@router.get("/patients/{mrn}/documents")
async def list_patient_documents(mrn: str):
    """Get all documents for a specific patient."""
    db: AsyncIOMotorDatabase = await get_database()

    cursor = db.documents.find({"patient_mrn": mrn})
    documents = await cursor.to_list(length=None)

    # Convert ObjectId to string
    for doc in documents:
        if "_id" in doc:
            doc["_id"] = str(doc["_id"])

    return {
        "patient_mrn": mrn,
        "documents": documents,
        "count": len(documents)
    }
