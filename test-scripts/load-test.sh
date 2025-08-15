#!/bin/bash

# Load Testing Script for LLM Demo
# Simulates concurrent users to test performance before cloud deployment

set -e

# Configuration
BASE_URL="http://localhost:5000"
CONCURRENT_USERS=50  # Start with 50, increase gradually
TEST_DURATION=60     # seconds
RAMP_UP_TIME=10      # seconds to reach full load

echo "🚀 Load Testing LLM Demo Application"
echo "   Target: $BASE_URL"
echo "   Concurrent Users: $CONCURRENT_USERS"
echo "   Duration: ${TEST_DURATION}s"
echo "   Ramp-up: ${RAMP_UP_TIME}s"

# Check if application is running
if ! curl -f "$BASE_URL/menu" >/dev/null 2>&1; then
    echo "❌ Application not responding at $BASE_URL"
    echo "   Please run ./test-local.sh first to start the application"
    exit 1
fi

# Create results directory
mkdir -p load-test-results
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="load-test-results/$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

echo "📊 Results will be saved to: $RESULTS_DIR"

# Function to make API requests
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
    status_code=$(echo "$response" | tail -c 8 | cut -d',' -f1)
    response_time=$(echo "$response" | tail -c 8 | cut -d',' -f2)
    
    echo "$user_id,$endpoint,$status_code,$response_time,$duration" >> "$RESULTS_DIR/requests.csv"
}

# Function to simulate a user session
simulate_user() {
    local user_id=$1
    local session_duration=$2
    
    echo "User $user_id starting session for ${session_duration}s"
    
    end_time=$(($(date +%s) + session_duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        # Random delay between requests (1-5 seconds)
        sleep $(echo "scale=2; $(($RANDOM % 4 + 1)) + $(($RANDOM % 100))/100" | bc -l 2>/dev/null || echo "2")
        
        # Choose random endpoint to test
        case $((RANDOM % 6)) in
            0)
                make_request "/menu" "GET" "" "$user_id"
                ;;
            1)
                make_request "/api/play" "POST" '{"messages":[{"role":"user","content":"Hello from user '$user_id'"}]}' "$user_id"
                ;;
            2)
                make_request "/api/security" "POST" '{"prompt":"test prompt from user '$user_id'","user_name":"user'$user_id'"}' "$user_id"
                ;;
            3)
                make_request "/api/orders/john_doe" "GET" "" "$user_id"
                ;;
            4)
                make_request "/api/ai-guard-status?user_name=user$user_id" "GET" "" "$user_id"
                ;;
            5)
                make_request "/api/rag-status?user_name=user$user_id" "GET" "" "$user_id"
                ;;
        esac
    done
    
    echo "User $user_id session completed"
}

# Initialize results file
echo "user_id,endpoint,status_code,response_time,total_time" > "$RESULTS_DIR/requests.csv"

echo "🏁 Starting load test..."

# Start monitoring
(
    echo "timestamp,cpu_percent,memory_mb,response_time_avg" > "$RESULTS_DIR/system_metrics.csv"
    while true; do
        timestamp=$(date +%s)
        
        # Get container stats if available
        if docker stats llmdemo-test-app --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | tail -n 1 | grep -q "%"; then
            stats=$(docker stats llmdemo-test-app --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | tail -n 1)
            cpu_percent=$(echo "$stats" | awk '{print $1}' | sed 's/%//')
            memory_usage=$(echo "$stats" | awk '{print $2}' | sed 's/MiB//')
        else
            cpu_percent="0"
            memory_usage="0"
        fi
        
        # Calculate average response time from recent requests
        if [ -f "$RESULTS_DIR/requests.csv" ]; then
            avg_response_time=$(tail -n 20 "$RESULTS_DIR/requests.csv" | awk -F',' 'NR>1 {sum+=$4; count++} END {if(count>0) print sum/count; else print 0}')
        else
            avg_response_time="0"
        fi
        
        echo "$timestamp,$cpu_percent,$memory_usage,$avg_response_time" >> "$RESULTS_DIR/system_metrics.csv"
        sleep 5
    done
) &
MONITOR_PID=$!

# Start users gradually (ramp-up)
echo "📈 Ramping up to $CONCURRENT_USERS users over ${RAMP_UP_TIME}s..."

user_pids=()
for i in $(seq 1 $CONCURRENT_USERS); do
    simulate_user "$i" "$TEST_DURATION" &
    user_pids+=($!)
    
    # Ramp-up delay
    if [ $i -lt $CONCURRENT_USERS ]; then
        sleep $(echo "scale=2; $RAMP_UP_TIME / $CONCURRENT_USERS" | bc -l 2>/dev/null || echo "0.2")
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

echo "✅ Load test completed!"

# Generate summary report
echo "📊 Generating test report..."

python3 -c "
import csv
import statistics
from collections import defaultdict

# Read request data
requests = []
status_codes = defaultdict(int)
endpoints = defaultdict(list)

try:
    with open('$RESULTS_DIR/requests.csv', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            requests.append(row)
            status_codes[row['status_code']] += 1
            endpoints[row['endpoint']].append(float(row['response_time']))
except:
    print('Could not read request data')
    exit(1)

total_requests = len(requests)
if total_requests == 0:
    print('No requests recorded')
    exit(1)

# Calculate statistics
response_times = [float(r['response_time']) for r in requests if r['response_time'] != '999']
if response_times:
    avg_response_time = statistics.mean(response_times)
    p95_response_time = sorted(response_times)[int(0.95 * len(response_times))]
    p99_response_time = sorted(response_times)[int(0.99 * len(response_times))]
else:
    avg_response_time = p95_response_time = p99_response_time = 0

success_rate = (status_codes.get('200', 0) / total_requests) * 100 if total_requests > 0 else 0

print(f'''
🎯 Load Test Results Summary
============================
Total Requests: {total_requests}
Success Rate: {success_rate:.1f}%
Average Response Time: {avg_response_time:.3f}s
95th Percentile: {p95_response_time:.3f}s
99th Percentile: {p99_response_time:.3f}s

Status Code Distribution:''')

for code, count in sorted(status_codes.items()):
    percentage = (count / total_requests) * 100
    print(f'  {code}: {count} ({percentage:.1f}%)')

print(f'''
Endpoint Performance:''')
for endpoint, times in endpoints.items():
    if times:
        avg_time = statistics.mean(times)
        print(f'  {endpoint}: {avg_time:.3f}s avg')

print(f'''
📁 Detailed results saved to: $RESULTS_DIR/
   - requests.csv: Individual request data
   - system_metrics.csv: System performance metrics
''')
" 2>/dev/null || echo "⚠️  Python3 not available for detailed analysis. Check CSV files manually."

echo ""
echo "🎉 Load test completed successfully!"
echo "📈 To test higher loads, increase CONCURRENT_USERS in the script"
echo "🔍 Review detailed results in: $RESULTS_DIR/"

# Quick recommendations
echo ""
echo "💡 Recommendations:"
if [ -f "$RESULTS_DIR/requests.csv" ]; then
    error_count=$(grep -v "200," "$RESULTS_DIR/requests.csv" | wc -l)
    if [ "$error_count" -gt 5 ]; then
        echo "   ⚠️  High error rate detected - check application logs"
    else
        echo "   ✅ Low error rate - application handling load well"
    fi
    
    # Check if we have slow responses
    slow_responses=$(awk -F',' '$4 > 2 {count++} END {print count+0}' "$RESULTS_DIR/requests.csv")
    if [ "$slow_responses" -gt 10 ]; then
        echo "   ⚠️  Some slow responses (>2s) - consider scaling up"
    else
        echo "   ✅ Response times look good"
    fi
fi

echo "   🚀 Ready for cloud deployment with $CONCURRENT_USERS concurrent users!"
