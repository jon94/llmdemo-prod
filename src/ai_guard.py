import requests
from .config import AI_GUARD_ENABLED, DD_API_KEY, DD_APP_KEY, AI_GUARD_URL, log


def evaluate_prompt_with_ai_guard(prompt: str, history: list = None) -> dict:
    """
    Evaluate a prompt using Datadog's AI Guard API for safety detection
    Returns: {"action": "ALLOW|DENY|ABORT", "reason": "explanation", "safe": bool}
    """
    global AI_GUARD_ENABLED, DD_API_KEY, DD_APP_KEY
    
    # Feature flag check - if disabled, skip entirely
    if not AI_GUARD_ENABLED:
        log.debug("AI Guard feature flag disabled - allowing request")
        return {"action": "ALLOW", "reason": "AI Guard feature disabled", "safe": True}
    
    # Configuration check - if enabled but keys missing, allow (fail open)
    if not DD_API_KEY or not DD_APP_KEY:
        log.debug("AI Guard enabled but keys not configured - allowing request")
        return {"action": "ALLOW", "reason": "AI Guard keys not configured", "safe": True}
    
    try:
        # Prepare the request payload
        payload = {
            "data": {
                "attributes": {
                    "history": history or [],
                    "current": {
                        "role": "user",
                        "content": prompt
                    }
                }
            }
        }
        
        headers = {
            "DD-API-KEY": DD_API_KEY,
            "DD-APPLICATION-KEY": DD_APP_KEY,
            "Content-Type": "application/json"
        }
        
        log.info(f"Evaluating prompt with AI Guard: {prompt[:100]}...")
        
        response = requests.post(AI_GUARD_URL, json=payload, headers=headers, timeout=5)
        
        if response.status_code == 200:
            result = response.json()
            action = result["data"]["attributes"]["action"]
            reason = result["data"]["attributes"]["reason"]
            
            log.info(f"AI Guard evaluation: {action} - {reason}")
            
            return {
                "action": action,
                "reason": reason,
                "safe": action == "ALLOW"
            }
        else:
            log.error(f"AI Guard API error: {response.status_code} - {response.text}")
            # Fail open - allow request if AI Guard is unavailable
            return {"action": "ALLOW", "reason": "AI Guard API unavailable", "safe": True}
            
    except requests.exceptions.Timeout:
        log.error("AI Guard API timeout")
        return {"action": "ALLOW", "reason": "AI Guard timeout", "safe": True}
    except Exception as e:
        log.error(f"AI Guard evaluation error: {e}")
        return {"action": "ALLOW", "reason": f"AI Guard error: {str(e)}", "safe": True} 