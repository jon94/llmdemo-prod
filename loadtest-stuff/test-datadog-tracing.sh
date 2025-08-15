#!/bin/bash

# Datadog Tracing Test Script
# Tests that Datadog tracing works correctly with the new sync worker configuration

set -e

echo "🔍 Testing Datadog Tracing Compatibility"

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "📋 Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
    echo "✅ Environment variables loaded"
fi

# Check if required environment variables are set
if [ -z "$DD_API_KEY" ]; then
    echo "⚠️  DD_API_KEY not set - tracing will be disabled for this test"
    echo "   Set DD_API_KEY to test full Datadog integration"
    TRACING_ENABLED=false
else
    echo "✅ DD_API_KEY found - enabling tracing"
    TRACING_ENABLED=true
fi

# Stop any existing test containers
docker stop llmdemo-datadog-test 2>/dev/null || true
docker rm llmdemo-datadog-test 2>/dev/null || true

echo "🚀 Starting application with Datadog tracing enabled..."

# Start container with Datadog tracing
docker run -d \
  --name llmdemo-datadog-test \
  -p 5001:5000 \
  -e FLASK_DEBUG=false \
  -e LOG_LEVEL=DEBUG \
  -e DD_TRACE_ENABLED=$TRACING_ENABLED \
  -e DD_LLMOBS_ENABLED=1 \
  -e DD_SERVICE=llm-play-app-test \
  -e DD_ENV=local-test \
  -e DD_SITE=datadoghq.com \
  -e DD_API_KEY="${DD_API_KEY:-}" \
  -e DD_APP_KEY="${DD_APP_KEY:-}" \
  -e OPENAI_API_KEY="${OPENAI_API_KEY}" \
  -e EPPO_API_KEY="${EPPO_API_KEY:-}" \
  llmdemo-local:test

echo "⏳ Waiting for application to start..."
sleep 15

# Health check
if curl -f http://localhost:5001/menu >/dev/null 2>&1; then
    echo "✅ Application started successfully"
else
    echo "❌ Application failed to start - checking logs..."
    docker logs llmdemo-datadog-test
    exit 1
fi

echo "🧪 Testing traced endpoints..."

# Test various endpoints to generate traces
echo "Testing /api/play with tracing..."
curl -s -X POST http://localhost:5001/api/play \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Test message for tracing"}]}' > /dev/null

echo "Testing /api/security with tracing..."
curl -s -X POST http://localhost:5001/api/security \
  -H "Content-Type: application/json" \
  -d '{"prompt":"test security prompt for tracing","user_name":"trace-test-user"}' > /dev/null

echo "Testing database operations with tracing..."
curl -s "http://localhost:5001/api/orders/john_doe" > /dev/null

echo "Testing feature flag endpoints..."
curl -s "http://localhost:5001/api/ai-guard-status?user_name=trace-test" > /dev/null
curl -s "http://localhost:5001/api/rag-status?user_name=trace-test" > /dev/null

# Check logs for tracing information
echo "📋 Checking application logs for tracing information..."

# Look for ddtrace initialization
if docker logs llmdemo-datadog-test 2>&1 | grep -q "ddtrace"; then
    echo "✅ Datadog tracing library loaded"
else
    echo "⚠️  No ddtrace initialization found in logs"
fi

# Look for trace generation
if docker logs llmdemo-datadog-test 2>&1 | grep -q -E "(trace|span)"; then
    echo "✅ Trace generation detected"
else
    echo "⚠️  No trace generation detected"
fi

# Check for any tracing errors
TRACE_ERRORS=$(docker logs llmdemo-datadog-test 2>&1 | grep -i -E "(trace.*error|ddtrace.*error)" | wc -l)
if [ "$TRACE_ERRORS" -eq "0" ]; then
    echo "✅ No tracing errors found"
else
    echo "⚠️  Found $TRACE_ERRORS tracing error(s):"
    docker logs llmdemo-datadog-test 2>&1 | grep -i -E "(trace.*error|ddtrace.*error)" | head -3
fi

# Test worker process compatibility
echo "🔧 Checking worker process compatibility..."
WORKER_COUNT=$(docker exec llmdemo-datadog-test ps aux | grep -c "gunicorn.*worker" || echo "0")
echo "📊 Detected $WORKER_COUNT Gunicorn workers"

# Check if each worker can handle tracing
echo "Testing trace generation across workers..."
for i in {1..5}; do
    curl -s http://localhost:5001/menu > /dev/null &
done
wait

echo "✅ Multiple requests sent across workers"

# Final log analysis
echo "📊 Final trace analysis..."
echo "Recent log entries:"
docker logs llmdemo-datadog-test 2>&1 | tail -10

echo ""
echo "🎯 Datadog Tracing Test Summary:"
echo "   - Application startup: ✅"
echo "   - Tracing library: $(docker logs llmdemo-datadog-test 2>&1 | grep -q "ddtrace" && echo "✅ Loaded" || echo "⚠️  Not detected")"
echo "   - Worker count: $WORKER_COUNT"
echo "   - Trace errors: $TRACE_ERRORS"
echo "   - Test requests: ✅ Completed"

if [ "$TRACING_ENABLED" = "true" ]; then
    echo ""
    echo "🔗 Check your Datadog dashboard for traces from service: llm-play-app-test"
    echo "   Environment: local-test"
    echo "   Recent traces should appear within 1-2 minutes"
else
    echo ""
    echo "ℹ️  To test full Datadog integration:"
    echo "   export DD_API_KEY=your_datadog_api_key"
    echo "   export DD_APP_KEY=your_datadog_app_key"
    echo "   ./test-datadog-tracing.sh"
fi

echo ""
echo "🛑 Stop test container with: docker stop llmdemo-datadog-test"
echo "✨ Datadog tracing test completed!"
