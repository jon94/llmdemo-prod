import os
import sys
import logging
from dotenv import load_dotenv
import ddtrace
from ddtrace.llmobs import LLMObs
from openai import OpenAI
from langchain_openai import ChatOpenAI
from pythonjsonlogger import jsonlogger

# Load environment variables and set up Datadog
load_dotenv()
ddtrace.patch_all(logging=True)
ddtrace.config.logs_injection = True

# OpenAI clients
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
langchain_client = ChatOpenAI(
    model="gpt-3.5-turbo",
    temperature=0.1,
    openai_api_key=os.getenv("OPENAI_API_KEY")
)

# AI Guard configuration
# Try to read API key from file first (Docker secrets), then environment variable
DD_API_KEY_FILE = os.getenv("DD_API_KEY_FILE")
if DD_API_KEY_FILE and os.path.exists(DD_API_KEY_FILE):
    try:
        with open(DD_API_KEY_FILE, 'r') as f:
            DD_API_KEY = f.read().strip()
    except Exception as e:
        DD_API_KEY = os.getenv("DD_API_KEY")
else:
    DD_API_KEY = os.getenv("DD_API_KEY")  # Fallback to environment variable

# Application Key support (required for v2 API)
DD_APP_KEY_FILE = os.getenv("DD_APP_KEY_FILE")
if DD_APP_KEY_FILE and os.path.exists(DD_APP_KEY_FILE):
    try:
        with open(DD_APP_KEY_FILE, 'r') as f:
            DD_APP_KEY = f.read().strip()
    except Exception as e:
        DD_APP_KEY = os.getenv("DD_APP_KEY")
else:
    DD_APP_KEY = os.getenv("DD_APP_KEY")  # Fallback to environment variable

AI_GUARD_ENABLED = os.getenv("AI_GUARD_ENABLED", "false").lower() == "true"  # Feature flag - disabled by default
AI_GUARD_URL = "https://dd.datadoghq.com/api/v2/ai-guard/evaluate"  # Updated to v2 endpoint

# Database configuration
DB_PATH = "secrets.db"

# Other configuration
CHAOS_ON = os.getenv("CHAOS_ON", "false").lower() == "true"

# JSON logging setup
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
fmt = (
    "%(asctime)s %(levelname)s %(name)s %(filename)s %(lineno)d "
    "%(message)s %(dd.service)s %(dd.env)s %(dd.trace_id)s %(dd.span_id)s"
)
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(jsonlogger.JsonFormatter(fmt))
root = logging.getLogger()
root.handlers = [handler]
root.setLevel(LOG_LEVEL)
log = logging.getLogger("llm-demo")

# Validate AI Guard feature flag and configuration after logger is available
if not AI_GUARD_ENABLED:
    log.info("🔒 AI Guard feature flag DISABLED - all requests will be allowed through")
elif AI_GUARD_ENABLED and (not DD_API_KEY or not DD_APP_KEY):
    missing_keys = []
    if not DD_API_KEY:
        missing_keys.append("DD_API_KEY")
    if not DD_APP_KEY:
        missing_keys.append("DD_APP_KEY")
    log.warning(f"🔒 AI Guard feature flag ENABLED but missing keys: {', '.join(missing_keys)}. AI Guard will be disabled.")
    AI_GUARD_ENABLED = False
else:
    api_key_source = "Docker secret file" if DD_API_KEY_FILE and os.path.exists(DD_API_KEY_FILE) else "environment"
    app_key_source = "Docker secret file" if DD_APP_KEY_FILE and os.path.exists(DD_APP_KEY_FILE) else "environment"
    log.info(f"🛡️ AI Guard feature flag ENABLED - v2 API active with API key from {api_key_source} and App key from {app_key_source}") 