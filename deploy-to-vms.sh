#!/bin/bash

# Deploy script for updating all backend VMs
# Usage: ./deploy-to-vms.sh

set -e

# Configuration
VMS=("llm-demo-vm2" "llm-demo-vm3" "llm-demo-vm4" "llm-demo-vm5" "llm-demo-vm6" "llm-demo-vm7" "llm-demo-vm8" "llm-demo-vm9" "llm-demo-vm10" "llm-demo-vm11")
ZONE="us-central1-a"
PROJECT_DIR="llmdemo-prod"
COMPOSE_FILE="docker-compose-backend.yml"

echo "🚀 Starting deployment to ${#VMS[@]} VMs..."
echo "=================================================="

# Function to run commands on a VM
run_on_vm() {
    local vm_name=$1
    local command=$2
    echo "📡 Running on $vm_name: $command"
    gcloud compute ssh $vm_name --zone=$ZONE --command="$command" --quiet
}

# Function to deploy to a single VM
deploy_to_vm() {
    local vm_name=$1
    echo ""
    echo "🔄 Deploying to $vm_name..."
    echo "----------------------------------------"
    
    # Navigate to project directory and update
    run_on_vm $vm_name "cd $PROJECT_DIR && git pull origin main"
    
    # Stop containers
    run_on_vm $vm_name "cd $PROJECT_DIR && docker compose -f $COMPOSE_FILE down"
    
    # Clean up Docker system
    run_on_vm $vm_name "docker system prune -a -f"
    
    # Start containers
    run_on_vm $vm_name "cd $PROJECT_DIR && docker compose -f $COMPOSE_FILE up -d"
    
    # Wait a moment for startup
    sleep 2
    
    # Check if containers are running
    echo "✅ Checking container status on $vm_name..."
    run_on_vm $vm_name "docker ps --format 'table {{.Names}}\t{{.Status}}'"
    
    echo "✅ $vm_name deployment complete!"
}

# Deploy to all VMs in parallel (optional - comment out if you prefer sequential)
deploy_parallel() {
    echo "🚀 Starting parallel deployment..."
    for vm in "${VMS[@]}"; do
        deploy_to_vm $vm &
    done
    
    # Wait for all background jobs to complete
    wait
    echo ""
    echo "🎉 All VMs deployed successfully!"
}

# Deploy to all VMs sequentially (safer, easier to debug)
deploy_sequential() {
    echo "🚀 Starting sequential deployment..."
    
    for vm in "${VMS[@]}"; do
        echo ""
        echo "📋 Next VM: $vm"
        read -p "Deploy to $vm? (y/n/q to quit): " confirm
        
        case $confirm in
            [Yy]* )
                deploy_to_vm $vm
                ;;
            [Nn]* )
                echo "⏭️  Skipping $vm"
                ;;
            [Qq]* )
                echo "🛑 Deployment stopped by user"
                return
                ;;
            * )
                echo "Please answer y, n, or q"
                # Ask again for the same VM
                ((i--))
                ;;
        esac
    done
    echo ""
    echo "🎉 Sequential deployment complete!"
}

# Health check function
health_check() {
    echo ""
    echo "🏥 Running health checks..."
    echo "================================"
    
    for vm in "${VMS[@]}"; do
        echo "Checking $vm..."
        # Get the internal IP and test the health endpoint
        internal_ip=$(gcloud compute instances describe $vm --zone=$ZONE --format="get(networkInterfaces[0].networkIP)")
        
        # Test health endpoint (you can modify this based on your app's health endpoint)
        if curl -s -f "http://$internal_ip:5000/menu" > /dev/null; then
            echo "✅ $vm ($internal_ip) - Healthy"
        else
            echo "❌ $vm ($internal_ip) - Not responding"
        fi
    done
}

# Main execution
echo "Choose deployment method:"
echo "1) Sequential (safer, easier to debug)"
echo "2) Parallel (faster)"
echo "3) Health check only"
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        deploy_sequential
        health_check
        ;;
    2)
        deploy_parallel
        health_check
        ;;
    3)
        health_check
        ;;
    *)
        echo "Invalid choice. Using sequential deployment."
        deploy_sequential
        health_check
        ;;
esac

echo ""
echo "🎯 Deployment complete! Your load balancer is ready."
echo "🌐 Test at: https://prod.dd-demo-sg-llm.com"
