#!/bin/bash

# Homepage Load Test - Test ONLY the / endpoint (frontend landing page)
set -e

CONCURRENT_USERS=${1:-400}
TEST_DURATION=${2:-300}
BASE_URL="https://prod.dd-demo-sg-llm.com"

echo "🏠 Homepage Load Test - Frontend Landing Page Only"
echo "================================================="
echo "   Target: $BASE_URL/"
echo "   Concurrent Users: $CONCURRENT_USERS"
echo "   Duration: ${TEST_DURATION}s"
echo "   Focus: Home page delivery performance ONLY"

# Check if application is running
if ! curl -f "$BASE_URL/" >/dev/null 2>&1; then
    echo "❌ Application not responding at $BASE_URL"
    exit 1
fi

# Create results directory
mkdir -p load-test-results
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="load-test-results/homepage_${CONCURRENT_USERS}users_$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

echo "user_id,status_code,response_time,content_length,timestamp" > "$RESULTS_DIR/homepage_requests.csv"

echo "🚀 Starting homepage-only load test..."

# Function to simulate a user hitting ONLY the homepage
simulate_homepage_user() {
    local user_id=$1
    local start_time=$(date +%s)
    local end_time=$((start_time + TEST_DURATION))
    
    while [ $(($(date +%s) - start_time)) -lt $TEST_DURATION ]; do
        # Only hit the homepage
        local url="$BASE_URL/"
        
        # Make request and time it with detailed metrics
        local request_start=$(date +%s)
        local curl_output=$(curl -s -o /dev/null -w "%{http_code}|%{time_total}|%{size_download}" \
            --max-time 30 --connect-timeout 10 \
            -H "User-Agent: HomepageLoadTest/1.0 (User $user_id)" \
            -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
            -H "Accept-Language: en-US,en;q=0.5" \
            -H "Connection: keep-alive" \
            "$url" 2>/dev/null)
        
        local request_end=$(date +%s)
        local response_time=$((request_end - request_start))
        
        # Parse curl output (now properly formatted)
        IFS='|' read -r status_code time_total size_download <<< "$curl_output"
        
        # Log result
        echo "$user_id,$status_code,$response_time,$size_download,$(date -Iseconds)" >> "$RESULTS_DIR/homepage_requests.csv"
        
        # Wait 2-5 seconds before next request (realistic user behavior)
        sleep $((RANDOM % 4 + 2))
    done
}

# Launch users
echo "🎯 Launching $CONCURRENT_USERS users (homepage only)..."
for i in $(seq 1 $CONCURRENT_USERS); do
    simulate_homepage_user $i &
    if [ $((i % 25)) -eq 0 ]; then
        echo "   Launched $i users..."
        sleep 0.1
    fi
done

echo "⏱️  Running for ${TEST_DURATION} seconds..."

# Progress monitoring every 30 seconds
monitor_progress() {
    local start_time=$(date +%s)
    while [ $(($(date +%s) - start_time)) -lt $TEST_DURATION ]; do
        sleep 30
        if [ -f "$RESULTS_DIR/homepage_requests.csv" ]; then
            local current_requests=$(tail -n +2 "$RESULTS_DIR/homepage_requests.csv" | wc -l)
            local elapsed=$(($(date +%s) - start_time))
            local remaining=$((TEST_DURATION - elapsed))
            local rps=$((current_requests / elapsed))
            echo "   Progress: ${elapsed}s elapsed, ${remaining}s remaining, ${current_requests} homepage requests (${rps} req/s)"
        fi
    done
}

# Start monitoring in background
monitor_progress &
MONITOR_PID=$!

# Wait for all users to complete
wait

# Stop monitoring
kill $MONITOR_PID 2>/dev/null || true

echo "✅ Homepage load test completed!"

# Detailed analysis
total_requests=$(tail -n +2 "$RESULTS_DIR/homepage_requests.csv" | wc -l)
successful_requests=$(tail -n +2 "$RESULTS_DIR/homepage_requests.csv" | awk -F',' '$2==200' | wc -l)
failed_requests=$((total_requests - successful_requests))

echo ""
echo "=== HOMEPAGE LOAD TEST RESULTS ==="
echo "Target Endpoint: / (homepage only)"
echo "Total Requests: $total_requests"
echo "Successful: $successful_requests"
echo "Failed: $failed_requests"

if [ $total_requests -gt 0 ]; then
    success_rate=$((successful_requests * 100 / total_requests))
    echo "Success Rate: ${success_rate}%"
    
    # Response time analysis
    echo ""
    echo "Response Time Distribution:"
    awk -F',' 'NR>1 && $2==200 {
        if($3<=1) instant++; 
        else if($3<=2) fast++; 
        else if($3<=5) medium++; 
        else slow++; 
        sum+=$3; count++
    } END {
        print "  Instant (0-1s): " instant " (" (instant/count*100) "%)"
        print "  Fast (1-2s): " fast " (" (fast/count*100) "%)"
        print "  Medium (2-5s): " medium " (" (medium/count*100) "%)"
        print "  Slow (>5s): " slow " (" (slow/count*100) "%)"
        print "  Average: " (sum/count) "s"
    }' "$RESULTS_DIR/homepage_requests.csv"
    
    # Content size analysis
    echo ""
    echo "Homepage Content Analysis:"
    avg_size=$(awk -F',' 'NR>1 && $2==200 {sum+=$4; count++} END {if(count>0) print sum/count/1024; else print 0}' "$RESULTS_DIR/homepage_requests.csv")
    echo "  Average homepage size: ${avg_size}KB"
    
    # Failure analysis
    if [ $failed_requests -gt 0 ]; then
        echo ""
        echo "Failure Analysis:"
        echo "  Failed requests: $failed_requests"
        echo "  Failure types:"
        awk -F',' 'NR>1 && $2!=200 {
            if($2=="000") timeout++; 
            else if($2>=500) server_error++; 
            else if($2>=400) client_error++; 
            else other++
        } END {
            if(timeout>0) print "    Timeouts (000): " timeout
            if(server_error>0) print "    Server errors (5xx): " server_error
            if(client_error>0) print "    Client errors (4xx): " client_error
            if(other>0) print "    Other errors: " other
        }' "$RESULTS_DIR/homepage_requests.csv"
    fi
    
    # Performance assessment
    echo ""
    echo "Performance Assessment:"
    if [ $success_rate -lt 85 ]; then
        echo "🔴 POOR - High failure rate for homepage delivery"
    elif [ $success_rate -lt 95 ]; then
        echo "🟡 FAIR - Some homepage delivery issues under load"
    else
        # Check average response time
        avg_time=$(awk -F',' 'NR>1 && $2==200 {sum+=$3; count++} END {if(count>0) print sum/count; else print 0}' "$RESULTS_DIR/homepage_requests.csv")
        if [ $(awk "BEGIN {print ($avg_time > 3)}") -eq 1 ]; then
            echo "🟡 FAIR - Homepage loads successfully but slowly"
        else
            echo "🟢 EXCELLENT - Homepage delivers well under load"
        fi
    fi
else
    echo "🔴 CRITICAL - No homepage requests completed"
fi

echo ""
echo "📁 Results saved to: $RESULTS_DIR/"
echo ""
echo "💡 This test focused exclusively on homepage (/) delivery performance"
echo "   For API endpoint testing, use: ./test-scripts/security-stress-test.sh"
