from ddtrace.llmobs import LLMObs
from ddtrace.llmobs.decorators import llm
from typing import Any

def finance_operations_eval(prompt: str, response: str) -> float:
    """Evaluate finance-related operations for compliance and accuracy"""
    
    # Check if it's a finance-related prompt
    finance_keywords = [
        "orders", "purchase", "payment", "amount", "price", "cost", 
        "transaction", "billing", "invoice", "refund", "balance", "top up"
    ]
    
    if not any(keyword in prompt.lower() for keyword in finance_keywords):
        return 0.0  # Not finance-related
    
    # Evaluate response quality for finance operations
    score = 0.0
    
    # Check if response contains actual financial data
    if any(char in response for char in ['$', '€', '£']) or 'amount' in response.lower():
        score += 0.4
    
    # Check if response is helpful and specific
    if len(response) > 50 and 'order' in response.lower():
        score += 0.3
    
    # Check if response avoids exposing sensitive info inappropriately
    sensitive_terms = ['admin', 'password', 'secret', 'token']
    if not any(term in response.lower() for term in sensitive_terms):
        score += 0.3
    
    return min(score, 1.0)

@llm(model_name="gpt-3.5-turbo", name="process_security_request", model_provider="openai")
def evaluate_finance_request(prompt, response):
    """Add this to your process_security_request workflow"""
    
    # Only evaluate finance operations
    finance_keywords = ["orders", "purchase", "payment", "amount", "price", "cost", "top up"]
    
    if any(keyword in prompt.lower() for keyword in finance_keywords):
        span_context = LLMObs.export_span(span=None)
        
        LLMObs.submit_evaluation(
            span=span_context,
            ml_app="shopassist",
            label="finance_operations",
            metric_type="score",
            value=finance_operations_eval(prompt, response),
            tags={"evaluation_type": "finance", "workflow": "security_request"}
        )