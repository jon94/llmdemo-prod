#!/bin/bash

# Connect Google Domain to existing Cloud DNS zone
set -e

DOMAIN_NAME="dd-demo-sg-llm.com"
PROJECT_ID="mcse-sandbox"

echo "🔗 Connecting Google Domain to Cloud DNS"
echo "========================================"

# Get the nameservers from your existing Cloud DNS zone
echo "📋 Getting nameservers from Cloud DNS zone..."
NAME_SERVERS=$(gcloud dns managed-zones describe llmdemo-zone \
    --project=$PROJECT_ID \
    --format="value(nameServers[].join(' '))")

echo ""
echo "✅ Your Cloud DNS nameservers:"
for ns in $NAME_SERVERS; do
    echo "   • $ns"
done

echo ""
echo "📋 Next Steps in Google Domains:"
echo "================================"
echo "1. Go to domains.google.com"
echo "2. Find your domain: $DOMAIN_NAME"
echo "3. Click 'Manage' → 'DNS'"
echo "4. Choose 'Use custom name servers'"
echo "5. Enter these nameservers:"
echo ""
for ns in $NAME_SERVERS; do
    echo "   $ns"
done
echo ""
echo "6. Save changes"
echo ""
echo "⏱️  DNS propagation will take 1-24 hours"
echo "🧪 Test with: nslookup $DOMAIN_NAME"
echo ""
echo "🔒 Once DNS works, set up HTTPS:"
echo "   ssh jonathan.lim@$(gcloud compute instances describe llmdemo-vm --zone=us-central1-a --project=$PROJECT_ID --format='get(networkInterfaces[0].accessConfigs[0].natIP)')"
echo "   sudo ./setup-vm-https.sh $DOMAIN_NAME"
