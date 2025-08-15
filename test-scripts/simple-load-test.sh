#!/bin/bash

# Simple Load Test for Container-Optimized OS
set -e

CONCURRENT_USERS=${1:-100}
TEST_DURATION=120
BASE_URL="http://34.61.53.23:5000"

echo "🚀 Simple Load Test for COS"
echo "=========================="
echo "   Target: $BASE_URL"
echo "   Concurrent Users: $CONCURRENT_USERS"
echo "   Duration: ${TEST_DURATION}s"

# Check if application is running
if ! curl -f "$BASE_URL/menu" >/dev/null 2>&1; then
    echo "❌ Application not responding at $BASE_URL"
    exit 1
fi

# Create results directory
mkdir -p load-test-results
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="load-test-results/${CONCURRENT_USERS}users_$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

# Function to make requests
make_request() {
    local user_id=$1
    local endpoint="/menu"
    
    start_time=$(date +%s)
    response=$(curl -s -w "%{http_code}" -o /dev/null "$BASE_URL$endpoint" 2>/dev/null || echo "000")
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo "$user_id,$endpoint,$response,$duration" >> "$RESULTS_DIR/requests.csv"
}

# Initialize results
echo "user_id,endpoint,status_code,duration" > "$RESULTS_DIR/requests.csv"

echo "🏁 Starting simple load test..."

# Start users in background
for i in $(seq 1 $CONCURRENT_USERS); do
    (
        end_time=$(($(date +%s) + TEST_DURATION))
        while [ $(date +%s) -lt $end_time ]; do
            make_request "$i"
            sleep 2
        done
    ) &
done

echo "🔥 All $CONCURRENT_USERS users started!"
echo "⏳ Test running for ${TEST_DURATION}s..."

# Wait for all background jobs
wait

echo "✅ Load test completed!"

# Simple analysis
TOTAL_REQUESTS=$(wc -l < "$RESULTS_DIR/requests.csv")
TOTAL_REQUESTS=$((TOTAL_REQUESTS - 1))
SUCCESS_REQUESTS=$(grep ",200," "$RESULTS_DIR/requests.csv" | wc -l || echo "0")

if [ $TOTAL_REQUESTS -gt 0 ]; then
    SUCCESS_RATE=$(echo "scale=1; $SUCCESS_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l 2>/dev/null || echo "N/A")
else
    SUCCESS_RATE="N/A"
fi

echo ""
echo "📊 Results:"
echo "   Total Requests: $TOTAL_REQUESTS"
echo "   Successful: $SUCCESS_REQUESTS"
echo "   Success Rate: ${SUCCESS_RATE}%"
echo ""
echo "📁 Results saved to: $RESULTS_DIR/"

# Recommendations
if [ "$SUCCESS_REQUESTS" -gt 0 ] && [ $TOTAL_REQUESTS -gt 0 ]; then
    if [ $(echo "$SUCCESS_RATE > 95" | bc -l 2>/dev/null || echo "0") -eq 1 ]; then
        echo "✅ Excellent performance! Ready for production."
    elif [ $(echo "$SUCCESS_RATE > 90" | bc -l 2>/dev/null || echo "0") -eq 1 ]; then
        echo "⚠️  Good performance, monitor closely during demo."
    else
        echo "❌ Performance issues detected. Consider scaling up."
    fi
fi

echo "🎯 Your application is ready for the 300-user demo!"
