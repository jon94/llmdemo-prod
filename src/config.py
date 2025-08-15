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

# OpenAI clients - balanced performance and reliability
client = OpenAI(
    api_key=os.getenv("OPENAI_API_KEY"),
    timeout=12,  # More reasonable timeout
    max_retries=1  # One retry for reliability
)
langchain_client = ChatOpenAI(
    model="gpt-3.5-turbo",  # Back to GPT-3.5-turbo
    temperature=0.1,
    openai_api_key=os.getenv("OPENAI_API_KEY"),
    request_timeout=12,  # Match OpenAI client timeout
    max_retries=1,  # One retry for reliability
    max_tokens=150  # Default token limit for faster responses
)

# AI Guard removed for performance optimization

# Eppo Feature Flag Configuration (keeping for other features)
EPPO_API_KEY = os.getenv("EPPO_API_KEY")  # Eppo SDK key

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
        # Use DD_ENV to determine Eppo environment, default to "production"
        eppo_environment = os.getenv("DD_ENV", "production").lower()
        if eppo_environment == "local":
            eppo_environment = "test"  # Map local to test environment
            
        client_config = Config(
            api_key=EPPO_API_KEY,
            assignment_logger=AssignmentLogger(),
            poll_interval_seconds=10,  # Poll for updates every 30 seconds
            poll_jitter_seconds=5      # Add some randomness to avoid thundering herd
        )
        # Note: base_url is handled automatically by the SDK
        eppo_client.init(client_config)
        log.info(f"🚩 Eppo client configured for environment: {eppo_environment}")
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

# is_ai_guard_enabled function removed for performance optimization

def is_rag_enabled(user_id: str = "anonymous") -> bool:
    """
    Check if RAG (database) is enabled using Eppo feature flag 'jon_lim_eppo'
    When True: Use RAG (database queries)
    When False: Use direct LLM responses (no database)
    Falls back to False (Direct LLM) if Eppo is not available
    """
    global eppo_initialized
    
    try:
        if eppo_initialized:
            import eppo_client
            client = eppo_client.get_instance()
            
            flag_result = client.get_boolean_assignment(
                "jon_lim_eppo",  # flag key
                user_id,         # subject key
                {"user_id": user_id},  # user properties
                False            # default value (Direct LLM by default)
            )
            log.debug(f"🚩 Eppo feature flag 'jon_lim_eppo' for user '{user_id}': {flag_result} ({'RAG' if flag_result else 'Direct LLM'})")
            return flag_result
        else:
            # Fall back to Direct LLM (default behavior)
            fallback_value = False
            log.debug(f"🔄 Falling back to Direct LLM (default): {fallback_value}")
            return fallback_value
        
    except Exception as e:
        log.error(f"❌ Error evaluating RAG feature flag: {e}")
        fallback_value = False
        log.debug(f"🔄 Error fallback to Direct LLM (default): {fallback_value}")
        return fallback_value

# AI Guard validation removed - performance optimization complete 