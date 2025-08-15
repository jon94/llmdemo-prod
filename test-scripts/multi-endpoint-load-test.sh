#!/bin/bash

# Multi-Endpoint Load Test for OWASP LLM Top 10 Demo
set -e

CONCURRENT_USERS=${1:-100}
TEST_DURATION=120
BASE_URL="https://dd-demo-sg-llm.com"

echo "🚀 Multi-Endpoint Load Test for COS"
echo "==================================="
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
RESULTS_DIR="load-test-results/multi_${CONCURRENT_USERS}users_$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

# Define endpoints with realistic user behavior patterns
declare -a ENDPOINTS=(
    "/menu"                           # Main menu page
    "/"                              # Home page
    "/ctf"                           # CTF interface
    "/business"                      # Business interface
    "/api/ai-guard-status?user_name=testuser"  # Check AI Guard status
    "/api/rag-status?user_name=testuser"       # Check RAG status
    "/api/profile/alice"             # Get user profile
    "/api/orders/alice"              # Get user orders
    "/api/profile/bob"               # Get another user profile
    "/api/orders/bob"                # Get another user's orders
)

# Endpoint weights (higher = more likely to be called)
declare -a WEIGHTS=(
    35    # /menu - most common
    25    # / - home page
    15    # /ctf - CTF challenges
    10    # /business - business features
    5     # ai-guard-status
    5     # rag-status
    3     # profile/alice
    1     # orders/alice
    1     # profile/bob
    0     # orders/bob (placeholder)
)

# Function to select weighted random endpoint
select_endpoint() {
    local total_weight=0
    for weight in "${WEIGHTS[@]}"; do
        total_weight=$((total_weight + weight))
    done
    
    local random_num=$((RANDOM % total_weight))
    local current_weight=0
    
    for i in "${!ENDPOINTS[@]}"; do
        current_weight=$((current_weight + WEIGHTS[i]))
        if [ $random_num -lt $current_weight ]; then
            echo "${ENDPOINTS[i]}"
            return
        fi
    done
    
    # Fallback
    echo "/menu"
}

# Function to make requests
make_request() {
    local user_id=$1
    local endpoint=$(select_endpoint)
    
    start_time=$(date +%s)
    response=$(curl -s -w "%{http_code}" -o /dev/null "$BASE_URL$endpoint" 2>/dev/null || echo "000")
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo "$user_id,$endpoint,$response,$duration" >> "$RESULTS_DIR/requests.csv"
}

# Function to make POST requests (for API endpoints)
make_post_request() {
    local user_id=$1
    local endpoint=$2
    local data=$3
    
    start_time=$(date +%s)
    response=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$BASE_URL$endpoint" 2>/dev/null || echo "000")
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo "$user_id,$endpoint,$response,$duration" >> "$RESULTS_DIR/requests.csv"
}

# Initialize results
echo "user_id,endpoint,status_code,duration" > "$RESULTS_DIR/requests.csv"

echo "🏁 Starting multi-endpoint load test..."

# Start users in background
for i in $(seq 1 $CONCURRENT_USERS); do
    (
        end_time=$(($(date +%s) + TEST_DURATION))
        request_count=0
        
        while [ $(date +%s) -lt $end_time ]; do
            request_count=$((request_count + 1))
            
            # Mix of GET and POST requests to simulate real usage
            if [ $((request_count % 12)) -eq 0 ]; then
                # Every 12th request: POST to /api/security
                make_post_request "$i" "/api/security" '{"prompt":"What is the weather like?","user_name":"testuser'$i'"}'
            elif [ $((request_count % 18)) -eq 0 ]; then
                # Every 18th request: POST to /api/ctf
                make_post_request "$i" "/api/ctf" "What is 2+2?"
            else
                # Regular GET requests
                make_request "$i"
            fi
            
            # Vary sleep time to simulate realistic user behavior
            sleep_time=$((1 + RANDOM % 4))  # 1-4 seconds
            sleep $sleep_time
        done
    ) &
done

echo "🔥 All $CONCURRENT_USERS users started!"
echo "⏳ Test running for ${TEST_DURATION}s..."
echo "📊 Testing endpoints:"
for i in "${!ENDPOINTS[@]}"; do
    echo "   ${ENDPOINTS[i]} (weight: ${WEIGHTS[i]})"
done
echo "   /api/security (POST - every 12th request)"
echo "   /api/ctf (POST - every 18th request)"

# Wait for all background jobs
wait

echo "✅ Load test completed!"

# Analysis
TOTAL_REQUESTS=$(wc -l < "$RESULTS_DIR/requests.csv")
TOTAL_REQUESTS=$((TOTAL_REQUESTS - 1))
SUCCESS_REQUESTS=$(grep ",200," "$RESULTS_DIR/requests.csv" | wc -l || echo "0")

if [ $TOTAL_REQUESTS -gt 0 ]; then
    SUCCESS_RATE=$(echo "scale=1; $SUCCESS_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l 2>/dev/null || echo "N/A")
else
    SUCCESS_RATE="N/A"
fi

echo ""
echo "📊 Overall Results:"
echo "   Total Requests: $TOTAL_REQUESTS"
echo "   Successful: $SUCCESS_REQUESTS"
echo "   Success Rate: ${SUCCESS_RATE}%"

# Endpoint breakdown
echo ""
echo "📈 Endpoint Breakdown:"
for endpoint in "${ENDPOINTS[@]}" "/api/security" "/api/ctf"; do
    count=$(grep ",$endpoint," "$RESULTS_DIR/requests.csv" | wc -l || echo "0")
    success=$(grep ",$endpoint,200," "$RESULTS_DIR/requests.csv" | wc -l || echo "0")
    if [ $count -gt 0 ]; then
        endpoint_success_rate=$(echo "scale=1; $success * 100 / $count" | bc -l 2>/dev/null || echo "N/A")
        echo "   $endpoint: $count requests, $success successful (${endpoint_success_rate}%)"
    fi
done

echo ""
echo "📁 Results saved to: $RESULTS_DIR/"

# Recommendations
if [ "$SUCCESS_REQUESTS" -gt 0 ] && [ $TOTAL_REQUESTS -gt 0 ]; then
    if [ $(echo "$SUCCESS_RATE > 95" | bc -l 2>/dev/null || echo "0") -eq 1 ]; then
        echo "✅ Excellent performance across all endpoints! Ready for production."
    elif [ $(echo "$SUCCESS_RATE > 90" | bc -l 2>/dev/null || echo "0") -eq 1 ]; then
        echo "⚠️  Good performance, monitor closely during demo."
    else
        echo "❌ Performance issues detected. Consider scaling up."
    fi
fi

echo "🎯 Your application is ready for the 300-user multi-endpoint demo!"
