# Build stage for service_chat
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code into service_chat directory for proper module structure
COPY . ./service_chat/

# Create model cache directory
RUN mkdir -p /app/models

# Note: Model download at build time is disabled by default.
# The model will be downloaded on first use at runtime.
# To download during build, use Docker BuildKit secrets:
#   docker build --secret id=hf_token,env=HUGGINGFACE_TOKEN \
#     --build-arg DOWNLOAD_MODEL=true -t carepath-chat-api .
ARG DOWNLOAD_MODEL=false
RUN --mount=type=secret,id=hf_token,required=false \
    if [ "$DOWNLOAD_MODEL" = "true" ]; then \
        echo "Downloading model during build..."; \
        export HUGGINGFACE_TOKEN=$(cat /run/secrets/hf_token 2>/dev/null || echo ""); \
        MODEL_CACHE_DIR=/app/models \
        python -c "from service_chat.services.model_manager import download_model_if_needed; download_model_if_needed()"; \
    else \
        echo "Skipping model download during build. Model will be downloaded on first use."; \
    fi

# Expose port
EXPOSE 8002

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV MODEL_CACHE_DIR=/app/models

# Run the application
CMD ["uvicorn", "service_chat.main:app", "--host", "0.0.0.0", "--port", "8002"]
