```
vi touch .env
# Environment variables for docker-compose
# Add your actual API keys below

# OpenAI API Key - required for the LLM application
OPENAI_API_KEY=sk-proj-xxxxxx

# Datadog API Key - required for monitoring and tracing
DD_API_KEY=xxxxxxxx
```
```
docker compose build --no-cache --pull
docker compose up --force-recreate -d
```