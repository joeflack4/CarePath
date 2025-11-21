"""LLM client with mock and real model support."""
import logging
from typing import Dict, Any, Optional, Tuple

logger = logging.getLogger(__name__)

# Global cache for model and tokenizer to avoid reloading on every request
_model_cache: Optional[Tuple] = None


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


def _load_model_cached():
    """
    Load the Qwen model with caching to avoid reloading on every request.

    Returns:
        tuple: (model, tokenizer)
    """
    global _model_cache

    if _model_cache is not None:
        logger.info("Using cached model and tokenizer")
        return _model_cache

    logger.info("Loading Qwen model for the first time...")
    from .model_manager import load_qwen_model

    _model_cache = load_qwen_model()
    return _model_cache


def generate_response_qwen(query: str, patient_summary: Dict[str, Any]) -> str:
    """
    Generate a response using Qwen3-4B-Thinking-2507 model.

    This function:
    - Loads Qwen3-4B-Thinking-2507 from Hugging Face (cached after first load)
    - Uses CPU-based inference
    - Formats the patient summary into a structured prompt
    - Returns the model's generated response

    Args:
        query: User's question
        patient_summary: Patient data from service_db_api

    Returns:
        str: LLM-generated response

    Raises:
        ImportError: If required dependencies are not installed
    """
    try:
        import torch
    except ImportError:
        raise ImportError(
            "torch is required for LLM inference. "
            "Install with: pip install torch transformers"
        )

    # Load model and tokenizer (cached after first call)
    model, tokenizer = _load_model_cached()

    # Build the prompt from RAG service
    from .rag_service import build_prompt
    prompt = build_prompt(query, patient_summary)

    # Tokenize input
    inputs = tokenizer(prompt, return_tensors="pt")

    # Generate response
    logger.info("Generating response with Qwen model...")
    with torch.no_grad():
        outputs = model.generate(
            inputs.input_ids,
            max_new_tokens=512,
            temperature=0.7,
            top_p=0.9,
            do_sample=True,
            pad_token_id=tokenizer.eos_token_id
        )

    # Decode and return response
    response = tokenizer.decode(outputs[0], skip_special_tokens=True)

    # Extract only the generated part (after the prompt)
    if prompt in response:
        response = response[len(prompt):].strip()

    logger.info("Response generated successfully")
    return response


def generate_response(mode: str, query: str, patient_summary: Dict[str, Any]) -> str:
    """
    Generate a response using the specified LLM mode.

    Args:
        mode: LLM mode ("mock", "qwen", or "Qwen3-4B-Thinking-2507")
        query: User's question
        patient_summary: Patient data from service_db_api

    Returns:
        str: Generated response

    Raises:
        ValueError: If mode is not recognized
    """
    if mode == "mock":
        return generate_response_mock(query, patient_summary)
    elif mode in ("qwen", "Qwen3-4B-Thinking-2507"):
        return generate_response_qwen(query, patient_summary)
    else:
        raise ValueError(
            f"Unknown LLM mode: {mode}. "
            f"Expected 'mock', 'qwen', or 'Qwen3-4B-Thinking-2507'."
        )
