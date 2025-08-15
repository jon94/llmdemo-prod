#!/bin/bash

# Enhanced Load Test Results Analyzer
set -e

RESULTS_DIR=${1:-""}

if [ -z "$RESULTS_DIR" ]; then
    echo "Usage: $0 <results_directory>"
    echo ""
    echo "Examples:"
    echo "  $0 load-test-results/ctf_300users_20250815_154529"
    echo "  $0 load-test-results/multi_100users_20250815_150428"
    echo "  $0 load-test-results/300users_20250815_153555"
    echo ""
    echo "Available results directories:"
    if [ -d "load-test-results" ]; then
        ls -1 load-test-results/ | head -10
    fi
    exit 1
fi

if [ ! -f "$RESULTS_DIR/requests.csv" ]; then
    echo "❌ Results file not found: $RESULTS_DIR/requests.csv"
    echo ""
    echo "Available results directories:"
    if [ -d "load-test-results" ]; then
        ls -1 load-test-results/
    fi
    exit 1
fi

# Detect test type from directory name
TEST_TYPE="standard"
if [[ "$RESULTS_DIR" == *"ctf_"* ]]; then
    TEST_TYPE="ctf"
elif [[ "$RESULTS_DIR" == *"multi_"* ]]; then
    TEST_TYPE="multi"
fi

echo "📊 Load Test Results Analysis"
echo "============================="
echo "Results from: $RESULTS_DIR"
echo "Test Type: $TEST_TYPE"
echo ""

CSV_FILE="$RESULTS_DIR/requests.csv"

# Check CSV format (with or without prompts column)
HEADER=$(head -n 1 "$CSV_FILE")
HAS_PROMPTS=false
if [[ "$HEADER" == *"prompt"* ]]; then
    HAS_PROMPTS=true
fi

# Overall statistics
TOTAL_REQUESTS=$(tail -n +2 "$CSV_FILE" | wc -l)
SUCCESS_REQUESTS=$(tail -n +2 "$CSV_FILE" | grep ",200," | wc -l || echo "0")
ERROR_REQUESTS=$(tail -n +2 "$CSV_FILE" | grep -v ",200," | wc -l || echo "0")

if [ $TOTAL_REQUESTS -gt 0 ]; then
    SUCCESS_RATE=$(echo "scale=2; $SUCCESS_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l 2>/dev/null || echo "N/A")
    ERROR_RATE=$(echo "scale=2; $ERROR_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l 2>/dev/null || echo "N/A")
else
    SUCCESS_RATE="N/A"
    ERROR_RATE="N/A"
fi

echo "🎯 Overall Performance:"
echo "   Total Requests: $TOTAL_REQUESTS"
echo "   Successful (200): $SUCCESS_REQUESTS (${SUCCESS_RATE}%)"
echo "   Errors: $ERROR_REQUESTS (${ERROR_RATE}%)"
echo ""

# Response time analysis
echo "⏱️  Response Time Analysis:"
FAST_REQUESTS=$(tail -n +2 "$CSV_FILE" | awk -F',' '$4 == 0' | wc -l || echo "0")
NORMAL_REQUESTS=$(tail -n +2 "$CSV_FILE" | awk -F',' '$4 == 1' | wc -l || echo "0")
SLOW_REQUESTS=$(tail -n +2 "$CSV_FILE" | awk -F',' '$4 >= 2' | wc -l || echo "0")

echo "   < 1 second: $FAST_REQUESTS requests"
echo "   1 second: $NORMAL_REQUESTS requests"
echo "   ≥ 2 seconds: $SLOW_REQUESTS requests"

if [ $TOTAL_REQUESTS -gt 0 ]; then
    fast_pct=$(echo "scale=1; $FAST_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l 2>/dev/null || echo "0")
    normal_pct=$(echo "scale=1; $NORMAL_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l 2>/dev/null || echo "0")
    slow_pct=$(echo "scale=1; $SLOW_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l 2>/dev/null || echo "0")
    echo "   Performance: ${fast_pct}% fast, ${normal_pct}% normal, ${slow_pct}% slow"
fi
echo ""

# Endpoint breakdown
echo "🔗 Endpoint Performance:"
echo "   Endpoint                                    | Requests | Success | Error | Success Rate"
echo "   -------------------------------------------|----------|---------|-------|-------------"

# Get unique endpoints and analyze each
tail -n +2 "$CSV_FILE" | cut -d',' -f2 | sort | uniq | while read -r endpoint; do
    if [ -n "$endpoint" ]; then
        total=$(tail -n +2 "$CSV_FILE" | grep ",$endpoint," | wc -l || echo "0")
        success=$(tail -n +2 "$CSV_FILE" | grep ",$endpoint,200," | wc -l || echo "0")
        error=$((total - success))
        
        if [ $total -gt 0 ]; then
            success_rate=$(echo "scale=1; $success * 100 / $total" | bc -l 2>/dev/null || echo "N/A")
        else
            success_rate="N/A"
        fi
        
        # Format endpoint name (truncate if too long)
        formatted_endpoint=$(echo "$endpoint" | cut -c1-42)
        printf "   %-42s | %8s | %7s | %5s | %10s%%\n" "$formatted_endpoint" "$total" "$success" "$error" "$success_rate"
    fi
done

echo ""

# CTF-specific analysis
if [ "$TEST_TYPE" = "ctf" ] && [ -f "$RESULTS_DIR/ctf_successes.csv" ]; then
    echo "🎯 CTF Challenge Analysis:"
    
    CTF_SUCCESSES=$(tail -n +2 "$RESULTS_DIR/ctf_successes.csv" | wc -l || echo "0")
    GUARDRAIL_BYPASSES=$(tail -n +2 "$RESULTS_DIR/ctf_successes.csv" | grep "guardrail_bypass" | wc -l || echo "0")
    SECRET_EXTRACTIONS=$(tail -n +2 "$RESULTS_DIR/ctf_successes.csv" | grep "secret_extraction" | wc -l || echo "0")
    
    echo "   Total CTF Successes: $CTF_SUCCESSES"
    echo "   Guardrail Bypasses: $GUARDRAIL_BYPASSES"
    echo "   Secret Extractions: $SECRET_EXTRACTIONS"
    
    if [ $CTF_SUCCESSES -gt 0 ]; then
        echo ""
        echo "🚨 DEMO GOLD: Successful CTF Bypasses Detected!"
        echo "   ============================================="
        tail -n +2 "$RESULTS_DIR/ctf_successes.csv" | while IFS=',' read -r user_id success_type method prompt; do
            # Clean up the prompt (remove quotes)
            clean_prompt=$(echo "$prompt" | sed 's/^"//;s/"$//')
            case $success_type in
                "CTF_SUCCESS")
                    echo "   🐕 GUARDRAIL BYPASS - User $user_id:"
                    echo "      Prompt: \"$clean_prompt\""
                    echo "      Result: AI recommended rabbits over dogs!"
                    ;;
                "SECURITY_SUCCESS")
                    echo "   🔓 SECRET EXTRACTION - User $user_id:"
                    echo "      Prompt: \"$clean_prompt\""
                    echo "      Result: Successfully extracted sensitive data!"
                    ;;
            esac
            echo ""
        done
        echo "   💡 These bypasses are PERFECT for demonstrating:"
        echo "      • Real-time security monitoring"
        echo "      • LLM-as-judge evaluation under load"
        echo "      • Datadog integration for AI safety events"
    else
        echo ""
        echo "   ℹ️  No CTF bypasses detected in this test run"
        echo "      Consider running with more aggressive prompts for demo purposes"
    fi
    echo ""
fi

# Error analysis
if [ $ERROR_REQUESTS -gt 0 ]; then
    echo "❌ Error Analysis:"
    tail -n +2 "$CSV_FILE" | grep -v ",200," | cut -d',' -f3 | sort | uniq -c | while read -r count code; do
        echo "   HTTP $code: $count requests"
    done
    echo ""
fi

# User distribution
UNIQUE_USERS=$(tail -n +2 "$CSV_FILE" | cut -d',' -f1 | sort | uniq | wc -l || echo "0")
echo "👥 User Distribution:"
echo "   Unique Users: $UNIQUE_USERS"

# Calculate requests per user
if [ $UNIQUE_USERS -gt 0 ] && [ $TOTAL_REQUESTS -gt 0 ]; then
    AVG_REQUESTS_PER_USER=$(echo "scale=1; $TOTAL_REQUESTS / $UNIQUE_USERS" | bc -l 2>/dev/null || echo "N/A")
    echo "   Avg Requests/User: $AVG_REQUESTS_PER_USER"
    
    # Show user activity distribution
    echo "   Most Active Users:"
    tail -n +2 "$CSV_FILE" | cut -d',' -f1 | sort | uniq -c | sort -nr | head -5 | while read -r count user; do
        echo "     User $user: $count requests"
    done
fi

echo ""

# Test-specific insights
case $TEST_TYPE in
    "ctf")
        echo "🎮 CTF Test Insights:"
        CTF_REQUESTS=$(tail -n +2 "$CSV_FILE" | grep ",/api/ctf," | wc -l || echo "0")
        SECURITY_REQUESTS=$(tail -n +2 "$CSV_FILE" | grep ",/api/security," | wc -l || echo "0")
        UI_REQUESTS=$(tail -n +2 "$CSV_FILE" | grep -E ",/ctf,|,/business," | wc -l || echo "0")
        
        echo "   Guardrail CTF attempts: $CTF_REQUESTS"
        echo "   ShopAssist CTF attempts: $SECURITY_REQUESTS"
        echo "   UI access requests: $UI_REQUESTS"
        
        if [ $CTF_REQUESTS -gt 0 ] && [ $SECURITY_REQUESTS -gt 0 ]; then
            echo "   ✅ Both CTF challenges tested under load"
        fi
        ;;
    "multi")
        echo "🌐 Multi-Endpoint Test Insights:"
        API_REQUESTS=$(tail -n +2 "$CSV_FILE" | grep ",/api/" | wc -l || echo "0")
        UI_REQUESTS=$(tail -n +2 "$CSV_FILE" | grep -v ",/api/" | wc -l || echo "0")
        
        echo "   API requests: $API_REQUESTS"
        echo "   UI requests: $UI_REQUESTS"
        
        if [ $API_REQUESTS -gt 0 ] && [ $UI_REQUESTS -gt 0 ]; then
            echo "   ✅ Both API and UI endpoints tested"
        fi
        ;;
    *)
        echo "📝 Standard Test Insights:"
        echo "   Single endpoint focused test"
        ;;
esac

echo ""

# Performance assessment
echo "🏆 Performance Assessment:"
if [ $(echo "$SUCCESS_RATE > 98" | bc -l 2>/dev/null || echo "0") -eq 1 ]; then
    echo "   ✅ EXCELLENT - Production ready!"
    ASSESSMENT="excellent"
elif [ $(echo "$SUCCESS_RATE > 95" | bc -l 2>/dev/null || echo "0") -eq 1 ]; then
    echo "   ✅ VERY GOOD - Ready for demo with monitoring"
    ASSESSMENT="very_good"
elif [ $(echo "$SUCCESS_RATE > 90" | bc -l 2>/dev/null || echo "0") -eq 1 ]; then
    echo "   ⚠️  GOOD - Monitor closely during demo"
    ASSESSMENT="good"
elif [ $(echo "$SUCCESS_RATE > 80" | bc -l 2>/dev/null || echo "0") -eq 1 ]; then
    echo "   ⚠️  FAIR - Consider optimization"
    ASSESSMENT="fair"
else
    echo "   ❌ POOR - Needs immediate attention"
    ASSESSMENT="poor"
fi

# Recommendations
echo ""
echo "💡 Recommendations:"

if [ $SLOW_REQUESTS -gt 0 ]; then
    slow_percentage=$(echo "scale=1; $SLOW_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l 2>/dev/null || echo "0")
    echo "   • ${slow_percentage}% of requests took ≥2 seconds - monitor response times"
fi

if [ $ERROR_REQUESTS -gt 0 ]; then
    echo "   • $ERROR_REQUESTS errors detected - investigate error patterns"
fi

if [ $UNIQUE_USERS -lt 50 ]; then
    echo "   • Consider testing with more concurrent users"
fi

# CTF-specific recommendations
if [ "$TEST_TYPE" = "ctf" ]; then
    if [ $CTF_SUCCESSES -gt 0 ]; then
        echo "   • ⚠️  CTF challenges were bypassed - review guardrail effectiveness"
        echo "   • Consider strengthening security measures if needed"
    else
        echo "   • ✅ No CTF bypasses detected - guardrails held under load"
    fi
fi

# Assessment-specific recommendations
case $ASSESSMENT in
    "excellent"|"very_good")
        echo "   • ✅ Ready for 300-user demo"
        echo "   • Monitor Datadog dashboards during demo"
        ;;
    "good")
        echo "   • ⚠️  Acceptable for demo with close monitoring"
        echo "   • Have scaling plan ready"
        ;;
    "fair"|"poor")
        echo "   • ❌ Consider optimization before demo"
        echo "   • Test with fewer users or scale up infrastructure"
        ;;
esac

echo "   • Monitor Datadog dashboards during actual demo"
echo "   • Have scaling plan ready if needed"

echo ""
echo "📈 Analysis complete!"
echo ""
echo "📁 Files analyzed:"
echo "   • $CSV_FILE"
if [ -f "$RESULTS_DIR/ctf_successes.csv" ]; then
    echo "   • $RESULTS_DIR/ctf_successes.csv"
fi