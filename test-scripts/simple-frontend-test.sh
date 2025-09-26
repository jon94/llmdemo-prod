#!/bin/bash

# Simple Frontend Load Test - No complex math, just basic HTTP testing
set -e

CONCURRENT_USERS=${1:-350}
TEST_DURATION=${2:-300}
BASE_URL="https://prod.dd-demo-sg-llm.com"

echo "🌐 Simple Frontend Load Test"
echo "============================"
echo "   Target: $BASE_URL"
echo "   Concurrent Users: $CONCURRENT_USERS"
echo "   Duration: ${TEST_DURATION}s"

# Check if application is running
if ! curl -f "$BASE_URL/" >/dev/null 2>&1; then
    echo "❌ Application not responding at $BASE_URL"
    exit 1
fi

# Create results directory
mkdir -p load-test-results
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="load-test-results/simple_frontend_${CONCURRENT_USERS}users_$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

# Frontend endpoints to test
declare -a ENDPOINTS=(
    "/"
    "/menu"
    "/business"
    "/ctf"
    "/static/style.css"
)

echo "user_id,endpoint,status_code,response_time,timestamp" > "$RESULTS_DIR/requests.csv"

echo "🚀 Starting simple frontend test..."

# Function to simulate a user
simulate_user() {
    local user_id=$1
    local start_time=$(date +%s)
    local end_time=$((start_time + TEST_DURATION))
    
    while [ $(($(date +%s) - start_time)) -lt $TEST_DURATION ]; do
        # Pick random endpoint
        local endpoint_index=$((RANDOM % ${#ENDPOINTS[@]}))
        local endpoint="${ENDPOINTS[$endpoint_index]}"
        local url="$BASE_URL$endpoint"
        
        # Make request and time it
        local request_start=$(date +%s)
        local status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "$url")
        local request_end=$(date +%s)
        local response_time=$((request_end - request_start))
        
        # Log result
        echo "$user_id,$endpoint,$status_code,$response_time,$(date -Iseconds)" >> "$RESULTS_DIR/requests.csv"
        
        # Wait 1-3 seconds before next request
        sleep $((RANDOM % 3 + 1))
    done
}

# Launch users
echo "🎯 Launching $CONCURRENT_USERS users..."
for i in $(seq 1 $CONCURRENT_USERS); do
    simulate_user $i &
    if [ $((i % 25)) -eq 0 ]; then
        echo "   Launched $i users..."
        sleep 0.2
    fi
done

echo "⏱️  Running for ${TEST_DURATION} seconds..."

# Simple progress monitoring
sleep $((TEST_DURATION / 2))
if [ -f "$RESULTS_DIR/requests.csv" ]; then
    current_requests=$(tail -n +2 "$RESULTS_DIR/requests.csv" | wc -l)
    echo "   Halfway: $current_requests requests so far..."
fi

# Wait for completion
wait

echo "✅ Test completed!"

# Simple analysis
total_requests=$(tail -n +2 "$RESULTS_DIR/requests.csv" | wc -l)
successful_requests=$(tail -n +2 "$RESULTS_DIR/requests.csv" | awk -F',' '$3==200' | wc -l)
failed_requests=$((total_requests - successful_requests))

echo ""
echo "=== RESULTS ==="
echo "Total Requests: $total_requests"
echo "Successful: $successful_requests"
echo "Failed: $failed_requests"

if [ $total_requests -gt 0 ]; then
    # Simple success rate calculation (avoid decimals)
    success_rate=$((successful_requests * 100 / total_requests))
    echo "Success Rate: ${success_rate}%"
    
    # Count slow requests (>5 seconds)
    slow_requests=$(tail -n +2 "$RESULTS_DIR/requests.csv" | awk -F',' '$4>5' | wc -l)
    echo "Slow Requests (>5s): $slow_requests"
    
    # Assessment
    if [ $success_rate -lt 80 ]; then
        echo "🔴 POOR - High failure rate"
    elif [ $slow_requests -gt $((total_requests / 4)) ]; then
        echo "🟡 FAIR - Many slow responses"
    elif [ $success_rate -lt 95 ]; then
        echo "🟡 FAIR - Some failures"
    else
        echo "🟢 GOOD - Frontend performing well"
    fi
else
    echo "🔴 CRITICAL - No requests completed"
fi

echo ""
echo "📁 Results saved to: $RESULTS_DIR/"
echo ""
echo "💡 To test with 350 users:"
echo "   $0 350 300"
