"""LLM client with mock and real model support."""
from typing import Dict, Any


def generate_response_mock(query: str, patient_summary: Dict[str, Any]) -> str:
    """
    Generate a mock response for testing.

    Args:
        query: User's question
        patient_summary: Patient data from service_db_api

    Returns:
        str: Mock response
    """
    return "This is a mock response from the AI assistant. In production, this would be replaced with a real LLM response."


def generate_response_qwen(query: str, patient_summary: Dict[str, Any]) -> str:
    """
    Generate a response using Qwen3-4B-Thinking-2507 model.

    TODO: Implement real model inference:
    - Load Qwen3-4B-Thinking-2507 from Hugging Face
    - Use CPU-based inference for MVP (optimize later)
    - Pass formatted prompt to model
    - Return generated response

    Args:
        query: User's question
        patient_summary: Patient data from service_db_api

    Returns:
        str: LLM-generated response
    """
    # Placeholder for future implementation
    raise NotImplementedError(
        "Qwen model inference not yet implemented. Use LLM_MODE='mock' for MVP."
    )


def generate_response(mode: str, query: str, patient_summary: Dict[str, Any]) -> str:
    """
    Generate a response using the specified LLM mode.

    Args:
        mode: LLM mode ("mock" or "qwen")
        query: User's question
        patient_summary: Patient data from service_db_api

    Returns:
        str: Generated response

    Raises:
        ValueError: If mode is not recognized
    """
    if mode == "mock":
        return generate_response_mock(query, patient_summary)
    elif mode == "qwen":
        return generate_response_qwen(query, patient_summary)
    else:
        raise ValueError(f"Unknown LLM mode: {mode}. Expected 'mock' or 'qwen'.")
