"""Triage endpoint for AI-powered patient assistance."""
import time
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from service_chat.config import settings
from service_chat.tracing import start_trace, log_span
from service_chat.scrub_phi import scrub
from service_chat.services import db_client, llm_client, rag_service

router = APIRouter()


class TriageRequest(BaseModel):
    """Request model for triage endpoint."""
    patient_mrn: str
    query: str


class TriageResponse(BaseModel):
    """Response model for triage endpoint."""
    trace_id: str
    patient_mrn: str
    query: str
    llm_mode: str
    response: str


@router.post("/triage", response_model=TriageResponse)
async def triage(request: TriageRequest):
    """
    AI-powered triage endpoint.

    This endpoint:
    1. Receives a patient query
    2. Fetches patient summary from service_db_api
    3. Builds a RAG-enhanced prompt
    4. Generates a response using LLM (mock in MVP)
    5. Returns the response with tracing information

    Args:
        request: Triage request with patient_mrn and query

    Returns:
        TriageResponse with AI-generated response and trace ID
    """
    # Start trace
    trace_id = start_trace()
    log_span(trace_id, "request_received", patient_mrn=request.patient_mrn)

    # Scrub PHI before logging (MVP: no-op, but structure is in place)
    scrubbed_request = scrub(request.dict())

    try:
        # Fetch patient summary from DB API
        start_time = time.time()
        log_span(trace_id, "db_api_patient_summary_start", patient_mrn=request.patient_mrn)

        try:
            patient_summary = await db_client.get_patient_summary(request.patient_mrn)
        except db_client.PatientNotFoundError:
            log_span(
                trace_id,
                "error",
                error_type="patient_not_found",
                patient_mrn=request.patient_mrn
            )
            raise HTTPException(
                status_code=404,
                detail={
                    "error": "Patient not found",
                    "trace_id": trace_id,
                    "patient_mrn": request.patient_mrn
                }
            )
        except db_client.DBAPIError as e:
            log_span(
                trace_id,
                "error",
                error_type="db_api_error",
                error_message=str(e)
            )
            raise HTTPException(
                status_code=500,
                detail={
                    "error": "Error fetching patient data",
                    "trace_id": trace_id
                }
            )

        db_elapsed_ms = round((time.time() - start_time) * 1000, 2)
        log_span(
            trace_id,
            "db_api_patient_summary_end",
            elapsed_ms=db_elapsed_ms
        )

        # Build prompt using RAG service
        prompt = rag_service.build_prompt(request.query, patient_summary)

        # Generate LLM response
        start_time = time.time()
        log_span(trace_id, "llm_inference_start", llm_mode=settings.LLM_MODE)

        try:
            llm_response = llm_client.generate_response(
                settings.LLM_MODE,
                request.query,
                patient_summary
            )
        except Exception as e:
            log_span(
                trace_id,
                "error",
                error_type="llm_error",
                error_message=str(e)
            )
            raise HTTPException(
                status_code=500,
                detail={
                    "error": "Error generating response",
                    "trace_id": trace_id
                }
            )

        llm_elapsed_ms = round((time.time() - start_time) * 1000, 2)
        log_span(
            trace_id,
            "llm_inference_end",
            elapsed_ms=llm_elapsed_ms
        )

        # Log completion
        log_span(trace_id, "request_completed")

        return TriageResponse(
            trace_id=trace_id,
            patient_mrn=request.patient_mrn,
            query=request.query,
            llm_mode=settings.LLM_MODE,
            response=llm_response
        )

    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        # Catch any unexpected errors
        log_span(
            trace_id,
            "error",
            error_type="unexpected_error",
            error_message=str(e)
        )
        raise HTTPException(
            status_code=500,
            detail={
                "error": "An unexpected error occurred",
                "trace_id": trace_id
            }
        )
