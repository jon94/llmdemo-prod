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

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy application code
COPY . .

# Expose the Flask/Gunicorn port
EXPOSE 5000

# Use Gunicorn with Datadog tracing
CMD ["ddtrace-run", "gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]