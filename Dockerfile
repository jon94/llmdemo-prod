# Use a slim Python base image
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DD_LLMOBS_ENABLED=1 \
    DD_LLMOBS_ML_APP=llm-play-app \
    DD_SERVICE=llm-play-app \
    DD_LLMOBS_AGENTLESS_ENABLED=false \
    DD_ENV=local \
    DD_TRACE_ENABLED=true \
    DD_LOGS_INJECTION=true \
    DD_VERSION=1.0.0

# Set working directory
WORKDIR /app

# Install OS dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies first (for better Docker layer caching)
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy modular source code structure
# Main application entry point
COPY app.py .

# Modular source code
COPY src/ src/

# Templates and static files
COPY templates/ templates/
COPY static/ static/

# Copy any additional configuration files
COPY *.yml *.yaml *.json *.env* ./

# Create directory for SQLite database (optional - SQLite will create if needed)
RUN mkdir -p data

# Expose the Flask/Gunicorn port
EXPOSE 5000

# Health check for the modular Flask app
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/menu || exit 1

# Use Gunicorn with Datadog tracing and production settings
CMD ["ddtrace-run", "gunicorn", \
     "--workers", "12", \
     "--worker-class", "sync", \
     "--threads", "4", \
     "--bind", "0.0.0.0:5000", \
     "--timeout", "45", \
     "--max-requests", "1000", \
     "--max-requests-jitter", "100", \
     "--preload", \
     "--log-level", "info", \
     "app:app"]