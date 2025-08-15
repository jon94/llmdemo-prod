#!/bin/bash

# Simple HTTPS Setup with Let's Encrypt
set -e

DOMAIN_NAME="dd-demo-sg-llm.com"
PROJECT_ID="mcse-sandbox"
VM_NAME="llmdemo-vm"
ZONE="us-central1-a"

echo "🔒 Setting up simple HTTPS for: $DOMAIN_NAME"
echo "============================================="

# Get VM external IP
echo "📍 Getting VM external IP..."
VM_IP=$(gcloud compute instances describe $VM_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID \
    --format="get(networkInterfaces[0].accessConfigs[0].natIP)")

echo "   VM IP: $VM_IP"

# Create DNS zone
echo "🌐 Creating Cloud DNS zone..."
gcloud dns managed-zones create llmdemo-zone \
    --dns-name=$DOMAIN_NAME \
    --description="LLM Demo Domain Zone" \
    --project=$PROJECT_ID || echo "Zone may already exist"

# Add DNS records
echo "📝 Adding DNS records..."
gcloud dns record-sets transaction start \
    --zone=llmdemo-zone \
    --project=$PROJECT_ID

# Remove existing records if they exist
gcloud dns record-sets transaction remove $VM_IP \
    --name=$DOMAIN_NAME \
    --ttl=300 \
    --type=A \
    --zone=llmdemo-zone \
    --project=$PROJECT_ID 2>/dev/null || true

gcloud dns record-sets transaction remove $VM_IP \
    --name=www.$DOMAIN_NAME \
    --ttl=300 \
    --type=A \
    --zone=llmdemo-zone \
    --project=$PROJECT_ID 2>/dev/null || true

# Add new records
gcloud dns record-sets transaction add $VM_IP \
    --name=$DOMAIN_NAME \
    --ttl=300 \
    --type=A \
    --zone=llmdemo-zone \
    --project=$PROJECT_ID

gcloud dns record-sets transaction add $VM_IP \
    --name=www.$DOMAIN_NAME \
    --ttl=300 \
    --type=A \
    --zone=llmdemo-zone \
    --project=$PROJECT_ID

gcloud dns record-sets transaction execute \
    --zone=llmdemo-zone \
    --project=$PROJECT_ID

# Open HTTP and HTTPS ports
echo "🚪 Opening firewall ports..."
gcloud compute firewall-rules create allow-http \
    --allow tcp:80 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow HTTP" \
    --project=$PROJECT_ID 2>/dev/null || echo "HTTP rule may already exist"

gcloud compute firewall-rules create allow-https \
    --allow tcp:443 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow HTTPS" \
    --project=$PROJECT_ID 2>/dev/null || echo "HTTPS rule may already exist"

# Get name servers
NAME_SERVERS=$(gcloud dns managed-zones describe llmdemo-zone \
    --project=$PROJECT_ID \
    --format="value(nameServers[].join(' '))")

echo ""
echo "✅ DNS Setup Complete!"
echo ""
echo "📋 Next Steps:"
echo "=============="
echo "1. Update your domain registrar nameservers to:"
for ns in $NAME_SERVERS; do
    echo "   • $ns"
done
echo ""
echo "2. Wait 1-2 hours for DNS propagation"
echo ""
echo "3. SSH into your VM and run the HTTPS setup:"
echo "   ssh jonathan.lim@$VM_IP"
echo "   curl -O https://raw.githubusercontent.com/your-repo/setup-vm-https.sh"
echo "   chmod +x setup-vm-https.sh"
echo "   sudo ./setup-vm-https.sh $DOMAIN_NAME"
echo ""
echo "4. Your site will be accessible at:"
echo "   • https://$DOMAIN_NAME"
echo "   • https://www.$DOMAIN_NAME"
echo ""
echo "💡 VM IP: $VM_IP"
