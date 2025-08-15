#!/bin/bash

# VM Deployment Script for LLM Demo
# Deploys docker-compose setup to a cloud VM instance

set -e

# Configuration - Update these values
PROJECT_ID="mcse-sandbox"
ZONE="us-central1-a"
INSTANCE_NAME="llmdemo-vm"
MACHINE_TYPE="n1-standard-8"  # 8 vCPU, 30GB RAM (Recommended for 300 users)
# MACHINE_TYPE="n1-standard-4"  # 4 vCPU, 15GB RAM (Conservative - good for testing)
# MACHINE_TYPE="n1-highmem-8"   # 8 vCPU, 52GB RAM (High-performance for LLM)
DISK_SIZE="50GB"

echo "🚀 Deploying LLM Demo to GCP VM Instance..."

# Step 1: Create VM instance with Container-Optimized OS
echo "📦 Creating VM instance..."
gcloud compute instances create $INSTANCE_NAME \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --machine-type=$MACHINE_TYPE \
    --network-interface=network-tier=PREMIUM,subnet=default \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=default \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --tags=http-server,https-server \
    --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image=projects/cos-cloud/global/images/family/cos-stable,mode=rw,size=$DISK_SIZE,type=projects/$PROJECT_ID/zones/$ZONE/diskTypes/pd-ssd \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=environment=production,app=llmdemo,please_keep_my_resource=true \
    --reservation-affinity=any

echo "✅ VM instance created successfully"

# Step 2: Configure firewall rules
echo "🔥 Setting up firewall rules..."
gcloud compute firewall-rules create llmdemo-allow-http \
    --project=$PROJECT_ID \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:5000 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server 2>/dev/null || echo "Firewall rule already exists"

echo "✅ Firewall rules configured"

# Step 3: Wait for instance to be ready
echo "⏳ Waiting for instance to be ready..."
gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format="get(status)" | grep -q "RUNNING"
sleep 30

# Step 4: Copy application files to VM
echo "📁 Copying application files to VM..."
# Create a temporary tar file excluding unnecessary files
tar -czf llmdemo-app.tar.gz \
    --exclude='.git' \
    --exclude='load-test-results' \
    --exclude='*.pyc' \
    --exclude='__pycache__' \
    --exclude='llmdemo-app.tar.gz' \
    .

# Copy and extract files
gcloud compute scp --zone=$ZONE llmdemo-app.tar.gz $INSTANCE_NAME:~/
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
    mkdir -p ~/llmdemo-prod
    cd ~/llmdemo-prod
    tar -xzf ../llmdemo-app.tar.gz
    rm ../llmdemo-app.tar.gz
"

# Clean up local tar file
rm llmdemo-app.tar.gz

echo "✅ Files copied to VM"

# Step 5: Setup and start application on VM
echo "🚀 Setting up application on VM..."
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
    # Install docker-compose
    sudo curl -L 'https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-linux-x86_64' -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Navigate to app directory
    cd ~/llmdemo-prod
    
    # Start the application
    sudo docker-compose up -d
    
    # Show status
    sudo docker-compose ps
"

echo "✅ Application started on VM"

# Step 6: Get external IP and show access information
EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format="get(networkInterfaces[0].accessConfigs[0].natIP)")

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📊 VM Instance Details:"
echo "   - Name: $INSTANCE_NAME"
echo "   - Zone: $ZONE"
echo "   - Machine Type: $MACHINE_TYPE"
echo "   - External IP: $EXTERNAL_IP"
echo ""
echo "🌐 Application URLs:"
echo "   - Main App: http://$EXTERNAL_IP:5000"
echo "   - Menu: http://$EXTERNAL_IP:5000/menu"
echo "   - Health Check: http://$EXTERNAL_IP:5000/menu"
echo ""
echo "🔧 Management Commands:"
echo "   - SSH to VM: gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo "   - View logs: gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command='cd ~/llmdemo-prod && sudo docker-compose logs'"
echo "   - Restart app: gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command='cd ~/llmdemo-prod && sudo docker-compose restart'"
echo "   - Stop VM: gcloud compute instances stop $INSTANCE_NAME --zone=$ZONE"
echo "   - Delete VM: gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE"
echo ""
echo "💰 Estimated Cost: ~$100-150/month for continuous operation"
echo "💡 Tip: Stop the VM when not in use to save costs"
echo ""
echo "✨ Ready for your 300-user demo!"
