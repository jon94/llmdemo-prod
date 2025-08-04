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

# Eppo Feature Flag Configuration
EPPO_API_KEY = os.getenv("EPPO_API_KEY")  # Eppo SDK key
AI_GUARD_URL = "https://dd.datadoghq.com/api/v2/ai-guard/evaluate"  # Updated to v2 endpoint

# Legacy support - keep this for backward compatibility
AI_GUARD_ENABLED = os.getenv("AI_GUARD_ENABLED", "false").lower() == "true"

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

# Initialize Eppo client after logger is available
eppo_initialized = False
try:
    if EPPO_API_KEY:
        import eppo_client
        from eppo_client.config import Config, AssignmentLogger
        
        # Configure and initialize Eppo client
        client_config = Config(
            api_key=EPPO_API_KEY,
            assignment_logger=AssignmentLogger()
        )
        # Note: base_url is handled automatically by the SDK
        eppo_client.init(client_config)
        eppo_initialized = True
        log.info("✅ Eppo client initialized successfully for feature flag 'jon_ai_guard'")
    else:
        log.warning("⚠️ EPPO_API_KEY not found - AI Guard feature flag will fall back to environment variables")
except ImportError:
    log.error("❌ Eppo SDK not installed. Run: pip install eppo-server-sdk>=3.0.0")
    eppo_initialized = False
except Exception as e:
    log.error(f"❌ Failed to initialize Eppo client: {e}")
    eppo_initialized = False

def is_ai_guard_enabled(user_id: str = "anonymous") -> bool:
    """
    Check if AI Guard is enabled using Eppo feature flag 'jon_ai_guard'
    Falls back to environment variable if Eppo is not available
    """
    global eppo_initialized
    
    try:
        if eppo_initialized:
            # Get Eppo client instance and use feature flag
            import eppo_client
            client = eppo_client.get_instance()
            
            flag_result = client.get_boolean_assignment(
                "jon_ai_guard",  # flag key
                user_id,         # subject key
                {"user_id": user_id},  # user properties
                False            # default value
            )
            log.debug(f"🚩 Eppo feature flag 'jon_ai_guard' for user '{user_id}': {flag_result}")
            return flag_result
        else:
            # Fall back to environment variable
            fallback_value = os.getenv("AI_GUARD_ENABLED", "false").lower() == "true"
            log.debug(f"🔄 Falling back to AI_GUARD_ENABLED environment variable: {fallback_value}")
            return fallback_value
        
    except Exception as e:
        log.error(f"❌ Error evaluating AI Guard feature flag: {e}")
        # Fall back to environment variable on error
        fallback_value = os.getenv("AI_GUARD_ENABLED", "false").lower() == "true"
        log.debug(f"🔄 Error fallback to AI_GUARD_ENABLED environment variable: {fallback_value}")
        return fallback_value

# Show deprecation warning if using legacy environment variable
if AI_GUARD_ENABLED:
    log.warning("⚠️ AI_GUARD_ENABLED environment variable is deprecated. Use Eppo feature flag 'jon_ai_guard' instead.")

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