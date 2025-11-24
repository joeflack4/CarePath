"""Hugging Face Inference API clients for LLM generation."""
import logging
import time
from typing import Dict, Any

import httpx

from service_chat.config import settings
from service_chat.services.rag_service import build_prompt

logger = logging.getLogger(__name__)


async def generate_response_hf_smollm2(
    query: str,
    patient_summary: Dict[str, Any]
) -> str:
    """
    Generate a response using HF SmolLM2 via free HF Inference API.

    This function:
    - Builds a prompt using the RAG service
    - Calls the free HF Inference API endpoint
    - Returns the generated text

    Args:
        query: User's question
        patient_summary: Patient data from service_db_api

    Returns:
        str: LLM-generated response

    Raises:
        httpx.TimeoutException: If request times out
        httpx.HTTPStatusError: If API returns non-2xx status
        Exception: For other errors
    """
    start_time = time.time()

    # Build the prompt from RAG service
    prompt = build_prompt(query, patient_summary)
    logger.info(f"Built prompt for HF SmolLM2 API (length={len(prompt)} chars)")

    # Prepare request
    url = f"https://router.huggingface.co/hf-inference/models/{settings.HF_SMOLLM2_MODEL_ID}"
    headers = {
        "Authorization": f"Bearer {settings.HF_API_TOKEN}",
        "Content-Type": "application/json"
    }
    payload = {
        "inputs": prompt,
        "parameters": {
            "max_new_tokens": settings.HF_MAX_NEW_TOKENS,
            "temperature": settings.HF_TEMPERATURE,
            "return_full_text": False
        }
    }

    # Make request with timeout
    async with httpx.AsyncClient(timeout=settings.HF_TIMEOUT_SECONDS) as client:
        logger.info(f"Calling HF SmolLM2 API (model={settings.HF_SMOLLM2_MODEL_ID}, timeout={settings.HF_TIMEOUT_SECONDS}s)")

        try:
            response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
        except httpx.TimeoutException as e:
            elapsed = time.time() - start_time
            logger.error(f"HF API timeout after {elapsed:.1f}s")
            raise Exception(f"Hugging Face API timed out after {elapsed:.1f}s. Try again or select a different model.")
        except httpx.HTTPStatusError as e:
            elapsed = time.time() - start_time
            logger.error(f"HF API returned {e.response.status_code}: {e.response.text}")

            # Provide helpful error messages
            if e.response.status_code == 401:
                raise Exception("Invalid Hugging Face API token. Please check your HF_API_TOKEN.")
            elif e.response.status_code == 404:
                raise Exception(f"Model '{settings.HF_SMOLLM2_MODEL_ID}' not found or not available on free tier.")
            elif e.response.status_code == 503:
                raise Exception(f"Model '{settings.HF_SMOLLM2_MODEL_ID}' is loading. Please wait a moment and try again.")
            elif e.response.status_code == 429:
                raise Exception("Hugging Face API rate limit exceeded. Please wait and try again.")
            else:
                raise Exception(f"Hugging Face API error ({e.response.status_code}): {e.response.text}")

    # Parse response
    try:
        result = response.json()

        # Handle different response formats
        if isinstance(result, list) and len(result) > 0:
            # Format: [{"generated_text": "..."}]
            generated_text = result[0].get("generated_text", "")
        elif isinstance(result, dict):
            # Format: {"generated_text": "..."}
            generated_text = result.get("generated_text", "")
        else:
            # Unexpected format
            logger.warning(f"Unexpected HF API response format: {type(result)}")
            generated_text = str(result)

        if not generated_text:
            raise Exception("Empty response from Hugging Face API")

        elapsed = time.time() - start_time
        logger.info(f"HF API response received in {elapsed:.1f}s (length={len(generated_text)} chars)")

        return generated_text.strip()

    except Exception as e:
        logger.error(f"Failed to parse HF API response: {e}")
        raise Exception(f"Failed to parse Hugging Face API response: {e}")


async def generate_response_hf_qwen(
    query: str,
    patient_summary: Dict[str, Any]
) -> str:
    """
    Generate a response using HF Qwen2.5 via Router API with provider.

    This function:
    - Builds a prompt using the RAG service
    - Calls the HF Router API with OpenAI-compatible format
    - Uses Together AI provider via model suffix
    - Returns the generated text

    Args:
        query: User's question
        patient_summary: Patient data from service_db_api

    Returns:
        str: LLM-generated response

    Raises:
        httpx.TimeoutException: If request times out
        httpx.HTTPStatusError: If API returns non-2xx status
        Exception: For other errors
    """
    start_time = time.time()

    # Build the prompt from RAG service
    prompt = build_prompt(query, patient_summary)
    logger.info(f"Built prompt for HF Qwen2.5 API (length={len(prompt)} chars)")

    # Prepare request (OpenAI-compatible format)
    url = "https://router.huggingface.co/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {settings.HF_API_TOKEN}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": settings.HF_QWEN_MODEL_ID,  # Includes provider suffix like ":together"
        "messages": [
            {"role": "user", "content": prompt}
        ],
        "max_tokens": settings.HF_MAX_NEW_TOKENS,
        "temperature": settings.HF_TEMPERATURE
    }

    # Make request with timeout
    async with httpx.AsyncClient(timeout=settings.HF_TIMEOUT_SECONDS) as client:
        logger.info(f"Calling HF Router API (model={settings.HF_QWEN_MODEL_ID}, timeout={settings.HF_TIMEOUT_SECONDS}s)")

        try:
            response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
        except httpx.TimeoutException as e:
            elapsed = time.time() - start_time
            logger.error(f"HF Router API timeout after {elapsed:.1f}s")
            raise Exception(f"Hugging Face Router API timed out after {elapsed:.1f}s. Try again or select a different model.")
        except httpx.HTTPStatusError as e:
            elapsed = time.time() - start_time
            logger.error(f"HF Router API returned {e.response.status_code}: {e.response.text}")

            # Provide helpful error messages
            if e.response.status_code == 401:
                raise Exception("Invalid Hugging Face API token. Please check your HF_API_TOKEN.")
            elif e.response.status_code == 404:
                raise Exception(f"Model '{settings.HF_QWEN_MODEL_ID}' not found or provider not available.")
            elif e.response.status_code == 503:
                raise Exception(f"Model '{settings.HF_QWEN_MODEL_ID}' is loading. Please wait a moment and try again.")
            elif e.response.status_code == 429:
                raise Exception("Hugging Face API rate limit exceeded. Please wait and try again.")
            else:
                raise Exception(f"Hugging Face Router API error ({e.response.status_code}): {e.response.text}")

    # Parse OpenAI-compatible response
    try:
        result = response.json()

        # OpenAI format: response["choices"][0]["message"]["content"]
        if "choices" in result and len(result["choices"]) > 0:
            generated_text = result["choices"][0]["message"]["content"]
        else:
            # Unexpected format
            logger.warning(f"Unexpected HF Router API response format: {type(result)}")
            raise Exception(f"Unexpected response format from Hugging Face Router API")

        if not generated_text:
            raise Exception("Empty response from Hugging Face Router API")

        elapsed = time.time() - start_time
        logger.info(f"HF Router API response received in {elapsed:.1f}s (length={len(generated_text)} chars)")

        return generated_text.strip()

    except Exception as e:
        logger.error(f"Failed to parse HF Router API response: {e}")
        raise Exception(f"Failed to parse Hugging Face Router API response: {e}")


def warmup_hf_model():
    """
    Warmup call for HuggingFace Router API.

    This is a synchronous function called during app startup.
    For Router API with providers like Together AI, warmup is less critical
    as the models are already hosted and ready.

    Does not block startup if warmup fails.
    """
    logger.info(f"HF Router API configured with model: {settings.HF_QWEN_MODEL_ID}")
    logger.info("Router API models are provider-hosted and don't require warmup")
    logger.info("First request may take 1-2 seconds")
