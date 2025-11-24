"""Triage endpoint for AI-powered patient assistance."""
import time
from datetime import datetime
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from service_chat.config import settings
from service_chat.tracing import start_trace, log_span
from service_chat.scrub_phi import scrub
from service_chat.services import db_client, llm_client, rag_service
from service_chat.services import chat_log_client

router = APIRouter()


class TriageRequest(BaseModel):
    """Request model for triage endpoint."""
    patient_mrn: str
    query: str
    llm_mode: Optional[str] = None  # Optional: uses DEFAULT_LLM_MODE if not provided


class TriageResponse(BaseModel):
    """Response model for triage endpoint."""
    trace_id: str
    patient_mrn: str
    query: str
    llm_mode: str
    response: str
    inference_time_ms: float
    conversation_id: Optional[str] = None  # ID of stored chat log


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

    # Track retrieval events during this request
    retrieval_events: List[Dict[str, Any]] = []

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

        # Record the retrieval event for patient summary fetch
        retrieval_events.append({
            "step_id": 1,
            "query_type": "db_query",
            "query": "Fetch patient summary by MRN",
            "endpoint": f"/patients/{request.patient_mrn}/summary",
            "latency_ms": db_elapsed_ms,
            "record_count": 1
        })

        # Build prompt using RAG service
        prompt = rag_service.build_prompt(request.query, patient_summary)

        # Determine which LLM mode to use (request parameter or default)
        llm_mode = request.llm_mode if request.llm_mode is not None else settings.DEFAULT_LLM_MODE

        # Generate LLM response
        start_time = time.time()
        log_span(trace_id, "llm_inference_start", llm_mode=llm_mode)

        try:
            llm_response = await llm_client.generate_response(
                llm_mode,
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

        # Build messages for chat log storage
        now = datetime.utcnow().isoformat() + "Z"
        messages = [
            {
                "role": "user",
                "content": request.query,
                "timestamp": now
            },
            {
                "role": "assistant",
                "content": llm_response,
                "timestamp": now,
                "model_name": llm_mode,
                "latency_ms": llm_elapsed_ms
            }
        ]

        # Store chat log (non-blocking, errors are logged but don't fail the request)
        log_span(trace_id, "chat_log_storage_start")
        chat_log_result = await chat_log_client.store_chat_log(
            patient_mrn=request.patient_mrn,
            messages=messages,
            retrieval_events=retrieval_events,
            trace_id=trace_id,
            channel="api"
        )
        conversation_id = chat_log_result.get("conversation_id") if chat_log_result else None
        log_span(trace_id, "chat_log_storage_end", conversation_id=conversation_id)

        # Log completion
        log_span(trace_id, "request_completed")

        return TriageResponse(
            trace_id=trace_id,
            patient_mrn=request.patient_mrn,
            query=request.query,
            llm_mode=llm_mode,
            response=llm_response,
            inference_time_ms=llm_elapsed_ms,
            conversation_id=conversation_id
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
