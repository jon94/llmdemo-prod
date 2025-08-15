#!/bin/bash

# Test AI Guard Configuration
echo "🔍 Testing AI Guard Configuration"
echo "================================="

# Test the API endpoint
echo "1. Testing AI Guard status endpoint:"
curl -s "https://dd-demo-sg-llm.com/api/ai-guard-status?user_name=testuser" | python3 -m json.tool

echo ""
echo "2. Testing with different user:"
curl -s "https://dd-demo-sg-llm.com/api/ai-guard-status?user_name=anonymous" | python3 -m json.tool

echo ""
echo "3. Check if Eppo is working by testing a security request:"
curl -s -X POST "https://dd-demo-sg-llm.com/api/security" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Test prompt","user_name":"testuser"}' | python3 -m json.tool

echo ""
echo "4. Check container logs for AI Guard initialization:"
echo "   Run on your VM: docker compose logs app | grep -i 'ai.guard\|eppo'"
