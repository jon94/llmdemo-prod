#!/bin/bash

# Deploy HTTPS setup to Container-Optimized OS VM
set -e

VM_NAME="llmdemo-vm"
ZONE="us-central1-a"
PROJECT_ID="mcse-sandbox"

echo "🐳 Deploying HTTPS setup to COS VM"
echo "=================================="

# Get VM IP
VM_IP=$(gcloud compute instances describe $VM_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID \
    --format="get(networkInterfaces[0].accessConfigs[0].natIP)")

echo "📍 VM IP: $VM_IP"

# Open HTTP and HTTPS ports
echo "🚪 Opening firewall ports..."
gcloud compute firewall-rules create allow-http \
    --allow tcp:80 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow HTTP" \
    --project=$PROJECT_ID 2>/dev/null || echo "HTTP rule already exists"

gcloud compute firewall-rules create allow-https \
    --allow tcp:443 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow HTTPS" \
    --project=$PROJECT_ID 2>/dev/null || echo "HTTPS rule already exists"

# Copy updated docker-compose.yml to VM
echo "📁 Copying updated docker-compose.yml to VM..."
gcloud compute scp docker-compose.yml $VM_NAME:~/llmdemo-prod/ \
    --zone=$ZONE \
    --project=$PROJECT_ID

echo ""
echo "🚀 Next Steps:"
echo "=============="
echo "1. SSH into your VM:"
echo "   gcloud compute ssh $VM_NAME --zone=$ZONE --project=$PROJECT_ID"
echo ""
echo "2. Navigate to your project and restart with HTTPS:"
echo "   cd ~/llmdemo-prod"
echo "   docker compose down"
echo "   docker compose up -d"
echo ""
echo "3. Wait 2-5 minutes for Let's Encrypt certificate generation"
echo ""
echo "4. Test your HTTPS site:"
echo "   • https://dd-demo-sg-llm.com"
echo "   • https://www.dd-demo-sg-llm.com"
echo ""
echo "5. Monitor the setup:"
echo "   docker compose logs nginx"
echo "   docker compose logs letsencrypt"
echo ""
echo "🎯 Your demo will be available at: https://dd-demo-sg-llm.com"
