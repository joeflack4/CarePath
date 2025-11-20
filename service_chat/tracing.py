"""Simple tracing helper for request tracking."""
import json
import logging
import uuid
from typing import Any

logger = logging.getLogger(__name__)


def start_trace() -> str:
    """
    Start a new trace and return a unique trace ID.

    Returns:
        str: UUID4 trace ID
    """
    trace_id = str(uuid.uuid4())
    return trace_id


def log_span(trace_id: str, span_name: str, **kwargs: Any) -> None:
    """
    Log a span within a trace.

    Args:
        trace_id: The trace ID
        span_name: Name of the span (e.g., "request_received", "db_api_call")
        **kwargs: Additional metadata to include in the span
    """
    span_data = {
        "trace_id": trace_id,
        "span_name": span_name,
        **kwargs
    }

    # Log as JSON for easy parsing
    logger.info(json.dumps(span_data))
