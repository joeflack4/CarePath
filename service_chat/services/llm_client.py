"""LLM client with mock and real model support."""
import logging
import asyncio
from concurrent.futures import ThreadPoolExecutor
from typing import Dict, Any, Optional, Tuple, Union

logger = logging.getLogger(__name__)

# Global cache for model and tokenizer to avoid reloading on every request
_model_cache: Optional[Tuple] = None

# Global cache for llama.cpp model
_llama_model_cache: Optional[Any] = None

# Thread pool executor for running blocking inference in background
# Using max_workers=1 to serialize inference requests (model isn't thread-safe for concurrent calls)
_executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="llm-inference")


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

    # Tokenize input with attention mask
    inputs = tokenizer(prompt, return_tensors="pt", padding=True)

    # Generate response
    # Note: CPU inference is slow (~3 sec/token). 128 tokens = ~6-7 min inference.
    # AWS ELB timeout increased to 600s to accommodate this.
    logger.info("Generating response with Qwen model (max_new_tokens=128)...")
    with torch.no_grad():
        outputs = model.generate(
            inputs.input_ids,
            attention_mask=inputs.attention_mask,
            max_new_tokens=128,  # Reduced from 512 to keep inference under 10 min on CPU
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


def _load_gguf_model_cached():
    """
    Load the GGUF model with llama.cpp caching.

    Returns:
        Llama: llama-cpp-python model instance
    """
    global _llama_model_cache

    if _llama_model_cache is not None:
        logger.info("Using cached llama.cpp model")
        return _llama_model_cache

    logger.info("Loading GGUF model with llama.cpp for the first time...")
    from .model_manager import download_gguf_model_if_needed

    model_path = download_gguf_model_if_needed()

    try:
        from llama_cpp import Llama
    except ImportError:
        raise ImportError(
            "llama-cpp-python is required for GGUF inference. "
            "Install with: pip install llama-cpp-python"
        )

    from ..config import settings

    _llama_model_cache = Llama(
        model_path=str(model_path),
        n_ctx=settings.GGUF_N_CTX,
        n_threads=settings.GGUF_N_THREADS,
        verbose=False
    )
    logger.info("GGUF model loaded successfully")
    return _llama_model_cache


def _generate_response_gguf_sync(query: str, patient_summary: Dict[str, Any]) -> str:
    """
    Synchronous GGUF inference (runs in background thread).

    Args:
        query: User's question
        patient_summary: Patient data from service_db_api

    Returns:
        str: LLM-generated response
    """
    import time
    import threading
    start_time = time.time()
    thread_name = threading.current_thread().name

    # Load model (cached after first call)
    logger.info(f"[{thread_name}] Loading model (cached)...")
    model = _load_gguf_model_cached()
    logger.info(f"[{thread_name}] Model loaded in {time.time() - start_time:.1f}s")

    # Build the prompt from RAG service
    prompt_start = time.time()
    from .rag_service import build_prompt
    prompt = build_prompt(query, patient_summary)
    logger.info(f"[{thread_name}] Prompt built in {time.time() - prompt_start:.1f}s (length={len(prompt)} chars)")

    from ..config import settings

    # Generate response
    inference_start = time.time()
    logger.info(f"[{thread_name}] Starting llama.cpp inference (max_tokens={settings.GGUF_MAX_TOKENS})...")
    logger.info(f"[{thread_name}] Calling model() - this may take several minutes on CPU...")

    output = model(
        prompt,
        max_tokens=settings.GGUF_MAX_TOKENS,
        temperature=0.7,
        top_p=0.9,
        presence_penalty=1.5,  # Recommended for Qwen GGUF to prevent repetition
        stop=["</s>", "<|endoftext|>", "<|im_end|>"]
    )

    inference_elapsed = time.time() - inference_start
    logger.info(f"[{thread_name}] model() call completed in {inference_elapsed:.1f}s")

    response = output["choices"][0]["text"].strip()
    total_elapsed = time.time() - start_time
    logger.info(f"[{thread_name}] Response generated in {total_elapsed:.1f}s total (inference={inference_elapsed:.1f}s)")
    return response


async def generate_response_gguf(query: str, patient_summary: Dict[str, Any]) -> str:
    """
    Generate a response using GGUF quantized model with llama.cpp.

    This is MUCH faster than transformers on CPU due to:
    - INT4 quantization (smaller model, faster math)
    - llama.cpp optimized CPU kernels

    Runs in background thread to keep event loop responsive for health checks.

    Args:
        query: User's question
        patient_summary: Patient data from service_db_api

    Returns:
        str: LLM-generated response
    """
    loop = asyncio.get_event_loop()
    # Run blocking inference in thread pool to keep event loop responsive
    response = await loop.run_in_executor(
        _executor,
        _generate_response_gguf_sync,
        query,
        patient_summary
    )
    return response


async def generate_response(mode: str, query: str, patient_summary: Dict[str, Any]) -> str:
    """
    Generate a response using the specified LLM mode.

    Args:
        mode: LLM mode - one of:
            - "mock": Returns a static test response
            - "gguf": Uses llama.cpp with GGUF quantized model (FAST on CPU)
            - "qwen" or "Qwen3-4B-Thinking-2507": Uses transformers (SLOW on CPU)
        query: User's question
        patient_summary: Patient data from service_db_api

    Returns:
        str: Generated response

    Raises:
        ValueError: If mode is not recognized
    """
    if mode == "mock":
        return generate_response_mock(query, patient_summary)
    elif mode == "gguf":
        return await generate_response_gguf(query, patient_summary)
    elif mode in ("qwen", "Qwen3-4B-Thinking-2507"):
        return generate_response_qwen(query, patient_summary)
    else:
        raise ValueError(
            f"Unknown LLM mode: {mode}. "
            f"Expected 'mock', 'gguf', 'qwen', or 'Qwen3-4B-Thinking-2507'."
        )
