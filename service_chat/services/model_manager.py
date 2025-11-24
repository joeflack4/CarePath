"""Model management for downloading and caching LLM models."""
import os
import logging
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)


def get_model_cache_dir() -> Path:
    """
    Get the directory for caching downloaded models.

    Returns:
        Path: Directory path for model cache
    """
    # Import settings here to get MODEL_CACHE_DIR from .env via pydantic-settings
    from ..config import settings

    # Use settings which loads from .env, fallback to env var, then default
    cache_dir = settings.MODEL_CACHE_DIR or os.environ.get("MODEL_CACHE_DIR", "./models")
    path = Path(cache_dir)
    path.mkdir(parents=True, exist_ok=True)
    return path


def download_model_if_needed(
    model_name: str = "Qwen/Qwen3-4B-Thinking-2507",
    token: Optional[str] = None
) -> Path:
    """
    Download a model from Hugging Face if it's not already cached.

    Args:
        model_name: Hugging Face model identifier
        token: Optional Hugging Face API token for authentication

    Returns:
        Path: Local path to the downloaded model

    Raises:
        ImportError: If required libraries are not installed
        Exception: If download fails
    """
    try:
        from huggingface_hub import snapshot_download
    except ImportError:
        raise ImportError(
            "huggingface-hub is required for model download. "
            "Install with: pip install huggingface-hub"
        )

    # Get token from environment if not provided
    if token is None:
        token = os.environ.get("HUGGINGFACE_TOKEN")

    cache_dir = get_model_cache_dir()
    model_path = cache_dir / model_name.replace("/", "--")

    # Check if model already exists
    if model_path.exists() and any(model_path.iterdir()):
        logger.info(f"Model {model_name} already cached at {model_path}")
        return model_path

    logger.info(f"Downloading model {model_name} to {model_path}...")

    try:
        downloaded_path = snapshot_download(
            repo_id=model_name,
            cache_dir=str(cache_dir),
            local_dir=str(model_path),
            local_dir_use_symlinks=False,
            token=token
        )
        logger.info(f"Model downloaded successfully to {downloaded_path}")
        return Path(downloaded_path)
    except Exception as e:
        logger.error(f"Failed to download model {model_name}: {e}")
        raise


def download_gguf_model_if_needed(
    model_name: Optional[str] = None,
    filename: Optional[str] = None,
    token: Optional[str] = None
) -> Path:
    """
    Download a GGUF model file from Hugging Face if not already cached.

    Args:
        model_name: Hugging Face model identifier (defaults to config.GGUF_MODEL_REPO)
        filename: Specific GGUF file to download (defaults to config.GGUF_MODEL_FILE)
        token: Optional Hugging Face API token for authentication

    Returns:
        Path: Local path to the downloaded GGUF file

    Raises:
        ImportError: If required libraries are not installed
        Exception: If download fails
    """
    from ..config import settings

    # Use config defaults if not provided
    if model_name is None:
        model_name = settings.GGUF_MODEL_REPO
    if filename is None:
        filename = settings.GGUF_MODEL_FILE

    try:
        from huggingface_hub import hf_hub_download
    except ImportError:
        raise ImportError(
            "huggingface-hub is required for model download. "
            "Install with: pip install huggingface-hub"
        )

    # Get token from environment if not provided
    if token is None:
        token = os.environ.get("HUGGINGFACE_TOKEN")

    cache_dir = get_model_cache_dir()
    model_path = cache_dir / filename

    # Check if model already exists
    if model_path.exists():
        logger.info(f"GGUF model already cached at {model_path}")
        return model_path

    logger.info(f"Downloading GGUF model {model_name}/{filename}...")

    try:
        downloaded_path = hf_hub_download(
            repo_id=model_name,
            filename=filename,
            cache_dir=str(cache_dir),
            local_dir=str(cache_dir),
            token=token
        )
        logger.info(f"GGUF model downloaded to {downloaded_path}")
        return Path(downloaded_path)
    except Exception as e:
        logger.error(f"Failed to download GGUF model: {e}")
        raise


def load_qwen_model(model_path: Optional[Path] = None):
    """
    Load the Qwen model and tokenizer.

    Args:
        model_path: Optional path to pre-downloaded model. If None, will download.

    Returns:
        tuple: (model, tokenizer) ready for inference

    Raises:
        ImportError: If required libraries are not installed
    """
    try:
        from transformers import AutoModelForCausalLM, AutoTokenizer
        import torch
    except ImportError:
        raise ImportError(
            "transformers and torch are required for LLM inference. "
            "Install with: pip install transformers torch"
        )

    # Download model if path not provided
    if model_path is None:
        model_path = download_model_if_needed()

    logger.info(f"Loading model from {model_path}...")

    # Load tokenizer and model
    tokenizer = AutoTokenizer.from_pretrained(str(model_path))
    model = AutoModelForCausalLM.from_pretrained(
        str(model_path),
        torch_dtype=torch.float16,  # Use float16 to reduce memory (~8GB vs 16GB for float32)
        device_map="cpu",
        low_cpu_mem_usage=True
    )

    logger.info("Model loaded successfully")
    return model, tokenizer
