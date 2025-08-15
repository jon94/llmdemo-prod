#!/bin/bash

# VM Load Testing Script
# Tests VM performance with configurable concurrent users

set -e

# Configuration
CONCURRENT_USERS=${1:-100}  # Default 100 users, or pass as argument
TEST_DURATION=120           # 2 minutes for more thorough testing
RAMP_UP_TIME=20            # 20 seconds to reach full load
BASE_URL="http://localhost:5000"

echo "🚀 VM Load Testing"
echo "=================="
echo "   Target: $BASE_URL"
echo "   Concurrent Users: $CONCURRENT_USERS"
echo "   Duration: ${TEST_DURATION}s"
echo "   Ramp-up: ${RAMP_UP_TIME}s"
echo ""

# Check if application is running
if ! curl -f "$BASE_URL/menu" >/dev/null 2>&1; then
    echo "❌ Application not responding at $BASE_URL"
    echo "   Make sure docker-compose is running"
    exit 1
fi

# Create results directory
mkdir -p vm-load-test-results
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="vm-load-test-results/${CONCURRENT_USERS}users_$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

echo "📊 Results will be saved to: $RESULTS_DIR"

# Start system monitoring
(
    echo "timestamp,cpu_percent,memory_percent,load_avg,disk_io" > "$RESULTS_DIR/system_metrics.csv"
    while true; do
        timestamp=$(date +%s)
        
        # Get system metrics
        cpu_percent=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
        memory_percent=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
        load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
        
        # Get disk I/O (simplified)
        disk_io=$(iostat -d 1 1 2>/dev/null | tail -n +4 | awk '{sum+=$4} END {print sum}' || echo "0")
        
        echo "$timestamp,$cpu_percent,$memory_percent,$load_avg,$disk_io" >> "$RESULTS_DIR/system_metrics.csv"
        sleep 5
    done
) &
MONITOR_PID=$!

# Function to make API requests (same as original load test)
make_request() {
    local endpoint=$1
    local method=$2
    local data=$3
    local user_id=$4
    
    start_time=$(date +%s.%N)
    
    if [ "$method" = "POST" ]; then
        response=$(curl -s -w "%{http_code},%{time_total}" -X POST \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$BASE_URL$endpoint" 2>/dev/null || echo "000,999")
    else
        response=$(curl -s -w "%{http_code},%{time_total}" \
            "$BASE_URL$endpoint" 2>/dev/null || echo "000,999")
    fi
    
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "999")
    
    # Extract status code and response time
    status_code=$(echo "$response" | tail -c 12 | cut -d',' -f1)
    response_time=$(echo "$response" | tail -c 12 | cut -d',' -f2)
    
    echo "$user_id,$endpoint,$status_code,$response_time,$duration" >> "$RESULTS_DIR/requests.csv"
}

# Function to simulate a user session
simulate_user() {
    local user_id=$1
    local session_duration=$2
    
    end_time=$(($(date +%s) + session_duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        # Random delay between requests (1-3 seconds for more aggressive testing)
        sleep $(echo "scale=2; $(($RANDOM % 2 + 1)) + $(($RANDOM % 100))/100" | bc -l 2>/dev/null || echo "1.5")
        
        # Choose random endpoint to test
        case $((RANDOM % 6)) in
            0)
                make_request "/menu" "GET" "" "$user_id"
                ;;
            1)
                make_request "/api/play" "POST" '{"messages":[{"role":"user","content":"VM test from user '$user_id'"}]}' "$user_id"
                ;;
            2)
                make_request "/api/security" "POST" '{"prompt":"VM security test from user '$user_id'","user_name":"vmuser'$user_id'"}' "$user_id"
                ;;
            3)
                make_request "/api/orders/john_doe" "GET" "" "$user_id"
                ;;
            4)
                make_request "/api/ai-guard-status?user_name=vmuser$user_id" "GET" "" "$user_id"
                ;;
            5)
                make_request "/api/rag-status?user_name=vmuser$user_id" "GET" "" "$user_id"
                ;;
        esac
    done
}

# Initialize results file
echo "user_id,endpoint,status_code,response_time,total_time" > "$RESULTS_DIR/requests.csv"

echo "🏁 Starting VM load test..."

# Start users gradually
user_pids=()
for i in $(seq 1 $CONCURRENT_USERS); do
    simulate_user "$i" "$TEST_DURATION" &
    user_pids+=($!)
    
    # Ramp-up delay
    if [ $i -lt $CONCURRENT_USERS ]; then
        sleep $(echo "scale=2; $RAMP_UP_TIME / $CONCURRENT_USERS" | bc -l 2>/dev/null || echo "0.2")
    fi
    
    # Progress indicator
    if [ $((i % 10)) -eq 0 ]; then
        echo "🔥 Started $i/$CONCURRENT_USERS users..."
    fi
done

echo "🔥 All $CONCURRENT_USERS users started!"
echo "⏳ Test running for ${TEST_DURATION}s..."

# Wait for all user sessions to complete
for pid in "${user_pids[@]}"; do
    wait "$pid"
done

# Stop monitoring
kill $MONITOR_PID 2>/dev/null || true

echo "✅ VM load test completed!"

# Generate enhanced report
echo "📊 Generating VM performance report..."

# Get final system stats
FINAL_CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
FINAL_MEM=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
FINAL_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')

# Analyze results
TOTAL_REQUESTS=$(wc -l < "$RESULTS_DIR/requests.csv" | tr -d ' ')
TOTAL_REQUESTS=$((TOTAL_REQUESTS - 1))  # Subtract header

SUCCESS_REQUESTS=$(grep ",200," "$RESULTS_DIR/requests.csv" | wc -l | tr -d ' ')
ERROR_REQUESTS=$((TOTAL_REQUESTS - SUCCESS_REQUESTS))

if [ $TOTAL_REQUESTS -gt 0 ]; then
    SUCCESS_RATE=$(echo "scale=1; $SUCCESS_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l)
    ERROR_RATE=$(echo "scale=1; $ERROR_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l)
else
    SUCCESS_RATE=0
    ERROR_RATE=0
fi

echo ""
echo "🎯 VM Load Test Results"
echo "======================="
echo "Test Configuration:"
echo "   - Concurrent Users: $CONCURRENT_USERS"
echo "   - Test Duration: ${TEST_DURATION}s"
echo "   - Total Requests: $TOTAL_REQUESTS"
echo ""
echo "Performance Results:"
echo "   - Success Rate: ${SUCCESS_RATE}%"
echo "   - Error Rate: ${ERROR_RATE}%"
echo "   - Successful Requests: $SUCCESS_REQUESTS"
echo "   - Failed Requests: $ERROR_REQUESTS"
echo ""
echo "System Resources (Final):"
echo "   - CPU Usage: ${FINAL_CPU}%"
echo "   - Memory Usage: ${FINAL_MEM}%"
echo "   - Load Average: $FINAL_LOAD"
echo ""

# Recommendations based on results
echo "💡 VM Sizing Recommendations:"
if (( $(echo "$FINAL_CPU > 80" | bc -l) )); then
    echo "   ⚠️  HIGH CPU USAGE (${FINAL_CPU}%) - Consider scaling up vCPUs"
elif (( $(echo "$FINAL_CPU > 60" | bc -l) )); then
    echo "   ⚠️  MODERATE CPU USAGE (${FINAL_CPU}%) - Monitor closely"
else
    echo "   ✅ CPU USAGE OK (${FINAL_CPU}%)"
fi

if (( $(echo "$FINAL_MEM > 80" | bc -l) )); then
    echo "   ⚠️  HIGH MEMORY USAGE (${FINAL_MEM}%) - Consider scaling up RAM"
elif (( $(echo "$FINAL_MEM > 60" | bc -l) )); then
    echo "   ⚠️  MODERATE MEMORY USAGE (${FINAL_MEM}%) - Monitor closely"
else
    echo "   ✅ MEMORY USAGE OK (${FINAL_MEM}%)"
fi

if (( $(echo "$ERROR_RATE > 5" | bc -l) )); then
    echo "   ❌ HIGH ERROR RATE (${ERROR_RATE}%) - Scale up immediately"
elif (( $(echo "$ERROR_RATE > 1" | bc -l) )); then
    echo "   ⚠️  MODERATE ERROR RATE (${ERROR_RATE}%) - Consider scaling up"
else
    echo "   ✅ ERROR RATE OK (${ERROR_RATE}%)"
fi

echo ""
echo "📁 Detailed results saved to: $RESULTS_DIR/"
echo "🔍 View system metrics: cat $RESULTS_DIR/system_metrics.csv"
echo "🔍 View request details: cat $RESULTS_DIR/requests.csv"
echo ""

# Next steps
if [ $CONCURRENT_USERS -lt 300 ]; then
    NEXT_TEST=$((CONCURRENT_USERS + 50))
    echo "🚀 Next test suggestion:"
    echo "   ./load-test-vm.sh $NEXT_TEST"
fi

echo "✨ VM load test completed!"
