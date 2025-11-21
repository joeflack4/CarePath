"""HTTP client for storing chat logs to service_db_api."""
import logging
from typing import Dict, Any, Optional, List

import httpx

from service_chat.config import settings

logger = logging.getLogger(__name__)


class ChatLogStorageError(Exception):
    """Raised when there's an error storing a chat log."""
    pass


async def store_chat_log(
    patient_mrn: str,
    messages: List[Dict[str, Any]],
    retrieval_events: Optional[List[Dict[str, Any]]] = None,
    trace_id: Optional[str] = None,
    channel: str = "api"
) -> Optional[Dict[str, Any]]:
    """
    Store a chat log to service_db_api.

    This function handles errors gracefully - it logs errors but doesn't
    raise exceptions to avoid failing the triage response if logging fails.

    Args:
        patient_mrn: Patient Medical Record Number
        messages: List of message dicts with role, content, timestamp, etc.
        retrieval_events: List of retrieval event dicts
        trace_id: Trace ID for request correlation
        channel: Channel identifier (default: "api")

    Returns:
        dict: Created chat log including conversation_id, or None if storage failed
    """
    url = f"{settings.DB_API_BASE_URL}/chat-logs"

    payload = {
        "patient_mrn": patient_mrn,
        "channel": channel,
        "messages": messages,
        "retrieval_events": retrieval_events,
        "trace_id": trace_id
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(url, json=payload)

            if response.status_code == 201:
                result = response.json()
                logger.info(
                    f"Chat log stored successfully: conversation_id={result.get('conversation_id')}, "
                    f"trace_id={trace_id}"
                )
                return result

            # Log the error but don't raise - chat log storage is non-critical
            logger.error(
                f"Failed to store chat log: status={response.status_code}, "
                f"response={response.text}, trace_id={trace_id}"
            )
            return None

    except httpx.RequestError as e:
        # Log the error but don't raise - chat log storage is non-critical
        logger.error(
            f"Error communicating with DB API for chat log storage: {str(e)}, "
            f"trace_id={trace_id}"
        )
        return None

    except Exception as e:
        # Catch any unexpected errors
        logger.error(
            f"Unexpected error storing chat log: {str(e)}, trace_id={trace_id}"
        )
        return None
