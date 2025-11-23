#!/usr/bin/env python
"""
Download Hugging Face models for local development or pre-caching.

Usage:
    python -m service_chat.utils.download_model
    python -m service_chat.utils.download_model --model "Qwen/Qwen3-4B-Thinking-2507"
    python -m service_chat.utils.download_model --output ./models

Environment variables:
    HUGGINGFACE_TOKEN: Optional authentication token for gated models
    MODEL_CACHE_DIR: Default directory for model storage
"""
import argparse
import logging
import os
import sys
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

DEFAULT_MODEL = "Qwen/Qwen3-4B-Thinking-2507"
DEFAULT_CACHE_DIR = os.environ.get("MODEL_CACHE_DIR", "./models")


def download_model(
    model_name: str = DEFAULT_MODEL,
    output_dir: str = DEFAULT_CACHE_DIR,
    token: str = None,
) -> Path:
    """
    Download a model from Hugging Face Hub.

    Args:
        model_name: Hugging Face model identifier (e.g., "Qwen/Qwen3-4B-Thinking-2507")
        output_dir: Directory to download the model to
        token: Optional Hugging Face API token for gated models

    Returns:
        Path to the downloaded model directory
    """
    try:
        from huggingface_hub import snapshot_download
    except ImportError:
        logger.error(
            "huggingface-hub is not installed. "
            "Run: make install-chat-llm"
        )
        sys.exit(1)

    # Get token from environment if not provided
    if token is None:
        token = os.environ.get("HUGGINGFACE_TOKEN")

    # Create output directory
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    # Model will be saved with sanitized name
    model_subdir = model_name.replace("/", "--")
    model_path = output_path / model_subdir

    # Check if already downloaded
    if model_path.exists() and any(model_path.iterdir()):
        logger.info(f"Model already exists at {model_path}")
        logger.info("To re-download, delete the directory first")
        return model_path

    logger.info(f"Downloading model: {model_name}")
    logger.info(f"Output directory: {model_path}")
    logger.info("This may take a while for large models (~8GB for Qwen3-4B)...")

    try:
        downloaded_path = snapshot_download(
            repo_id=model_name,
            cache_dir=str(output_path),
            local_dir=str(model_path),
            local_dir_use_symlinks=False,
            token=token,
        )
        logger.info(f"Download complete: {downloaded_path}")
        return Path(downloaded_path)
    except Exception as e:
        logger.error(f"Download failed: {e}")
        raise


def main():
    parser = argparse.ArgumentParser(
        description="Download Hugging Face models for local development",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Download default Qwen model to ./models/
    python -m service_chat.utils.download_model

    # Download to custom directory
    python -m service_chat.utils.download_model --output /path/to/models

    # Download a different model
    python -m service_chat.utils.download_model --model "microsoft/phi-2"

    # Use Hugging Face token (for gated models)
    HUGGINGFACE_TOKEN=hf_xxx python -m service_chat.utils.download_model
        """
    )

    parser.add_argument(
        "--model", "-m",
        default=DEFAULT_MODEL,
        help=f"Hugging Face model identifier (default: {DEFAULT_MODEL})"
    )

    parser.add_argument(
        "--output", "-o",
        default=DEFAULT_CACHE_DIR,
        help=f"Output directory for downloaded model (default: {DEFAULT_CACHE_DIR})"
    )

    parser.add_argument(
        "--token", "-t",
        default=None,
        help="Hugging Face API token (or set HUGGINGFACE_TOKEN env var)"
    )

    args = parser.parse_args()

    try:
        model_path = download_model(
            model_name=args.model,
            output_dir=args.output,
            token=args.token,
        )
        print(f"\n✅ Model downloaded to: {model_path}")
        print(f"\nTo use this model, set:")
        print(f"  export MODEL_CACHE_DIR={args.output}")
        print(f"  export LLM_MODE=Qwen3-4B-Thinking-2507")
    except Exception as e:
        logger.error(f"Failed to download model: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
