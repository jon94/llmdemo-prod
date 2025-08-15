#!/bin/bash

# VM Sizing Guide and Testing Script
# Helps determine optimal VM size for your workload

echo "🎯 VM Sizing Guide for LLM Demo"
echo "================================"

# Function to estimate capacity
estimate_capacity() {
    local vcpus=$1
    local ram_gb=$2
    local workers_per_cpu=3
    local threads_per_worker=4
    
    local total_workers=$((vcpus * workers_per_cpu))
    local concurrent_capacity=$((total_workers * threads_per_worker))
    
    echo "📊 Estimated Capacity:"
    echo "   - vCPUs: $vcpus"
    echo "   - RAM: ${ram_gb}GB"
    echo "   - Gunicorn workers: $total_workers"
    echo "   - Concurrent capacity: $concurrent_capacity requests"
    echo "   - Estimated users: $((concurrent_capacity * 4)) (with 4:1 ratio)"
    echo ""
}

echo "🔍 VM Size Recommendations:"
echo ""

echo "💚 CONSERVATIVE (Start Here):"
echo "GCP: n1-standard-4 | AWS: m5.xlarge"
estimate_capacity 4 15

echo "🎯 RECOMMENDED (300 users):"
echo "GCP: n1-standard-8 | AWS: m5.2xlarge"
estimate_capacity 8 30

echo "🚀 HIGH PERFORMANCE:"
echo "GCP: n1-highmem-8 | AWS: r5.2xlarge"
estimate_capacity 8 64

echo "📋 Testing Strategy:"
echo "1. Start with CONSERVATIVE size"
echo "2. Deploy and run load test"
echo "3. Monitor CPU/memory usage"
echo "4. Scale up if needed"
echo ""

echo "🧪 Load Testing Commands:"
echo "# Test with 100 users"
echo "ssh -i ~/.ssh/key.pem user@VM_IP 'cd ~/llmdemo-prod && ./load-test-vm.sh 100'"
echo ""
echo "# Test with 200 users"  
echo "ssh -i ~/.ssh/key.pem user@VM_IP 'cd ~/llmdemo-prod && ./load-test-vm.sh 200'"
echo ""
echo "# Test with 300 users"
echo "ssh -i ~/.ssh/key.pem user@VM_IP 'cd ~/llmdemo-prod && ./load-test-vm.sh 300'"
echo ""

echo "📊 Monitoring Commands:"
echo "# Check resource usage"
echo "ssh -i ~/.ssh/key.pem user@VM_IP 'htop'"
echo ""
echo "# Check container stats"
echo "ssh -i ~/.ssh/key.pem user@VM_IP 'cd ~/llmdemo-prod && docker stats'"
echo ""
echo "# Check application logs"
echo "ssh -i ~/.ssh/key.pem user@VM_IP 'cd ~/llmdemo-prod && docker-compose logs -f'"
echo ""

echo "💡 Scaling Decision Matrix:"
echo "CPU Usage > 80%: Scale up vCPUs"
echo "Memory Usage > 80%: Scale up RAM"
echo "Response time > 2s: Scale up both"
echo "Error rate > 1%: Scale up immediately"
echo ""

echo "💰 Cost Comparison (Monthly):"
echo "GCP n1-standard-4:  ~$120"
echo "GCP n1-standard-8:  ~$240"
echo "AWS m5.xlarge:      ~$140"
echo "AWS m5.2xlarge:     ~$280"
echo ""

echo "🎯 Recommendation for 300-user demo:"
echo "Start with n1-standard-4 (GCP) or m5.xlarge (AWS)"
echo "Monitor performance and scale up if needed"
echo "This gives you headroom and cost control"
