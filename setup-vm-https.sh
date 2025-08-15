#!/bin/bash

# VM-side HTTPS setup with Let's Encrypt
set -e

DOMAIN_NAME=${1:-"dd-demo-sg-llm.com"}

if [ -z "$DOMAIN_NAME" ]; then
    echo "Usage: $0 <domain_name>"
    echo "Example: $0 dd-demo-sg-llm.com"
    exit 1
fi

echo "🔒 Setting up HTTPS on VM for: $DOMAIN_NAME"
echo "==========================================="

# Update system
echo "📦 Updating system packages..."
sudo apt-get update

# Install nginx
echo "🌐 Installing Nginx..."
sudo apt-get install -y nginx

# Install certbot
echo "🔐 Installing Certbot (Let's Encrypt)..."
sudo apt-get install -y certbot python3-certbot-nginx

# Create nginx configuration
echo "⚙️  Configuring Nginx..."
sudo tee /etc/nginx/sites-available/llmdemo > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    
    # Let's Encrypt challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect all other HTTP traffic to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    
    # SSL certificates (will be added by certbot)
    # ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    
    # Proxy to your Flask app
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
        
        # WebSocket support (if needed)
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# Enable the site
echo "🔗 Enabling Nginx site..."
sudo ln -sf /etc/nginx/sites-available/llmdemo /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
echo "🧪 Testing Nginx configuration..."
sudo nginx -t

# Start nginx
echo "🚀 Starting Nginx..."
sudo systemctl enable nginx
sudo systemctl restart nginx

# Wait for DNS propagation check
echo "🌐 Checking DNS propagation..."
echo "Waiting for $DOMAIN_NAME to resolve to this server..."

for i in {1..30}; do
    if nslookup $DOMAIN_NAME | grep -q "$(curl -s ifconfig.me)"; then
        echo "✅ DNS propagated successfully!"
        break
    else
        echo "⏳ Waiting for DNS propagation... ($i/30)"
        sleep 10
    fi
done

# Get SSL certificate
echo "🔐 Obtaining SSL certificate..."
sudo certbot --nginx \
    -d $DOMAIN_NAME \
    -d www.$DOMAIN_NAME \
    --non-interactive \
    --agree-tos \
    --email admin@$DOMAIN_NAME \
    --redirect

# Set up auto-renewal
echo "🔄 Setting up SSL certificate auto-renewal..."
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Test the setup
echo "🧪 Testing HTTPS setup..."
sleep 5

if curl -k -s https://localhost | grep -q "LLM Demo"; then
    echo "✅ HTTPS setup successful!"
else
    echo "⚠️  HTTPS setup may need manual verification"
fi

echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""
echo "Your site is now available at:"
echo "• https://$DOMAIN_NAME"
echo "• https://www.$DOMAIN_NAME"
echo "• http://$DOMAIN_NAME (redirects to HTTPS)"
echo ""
echo "🔐 SSL Certificate Details:"
sudo certbot certificates
echo ""
echo "🔄 Auto-renewal status:"
sudo systemctl status certbot.timer --no-pager
echo ""
echo "💡 To test renewal:"
echo "sudo certbot renew --dry-run"
echo ""
echo "🎯 Your demo is ready at: https://$DOMAIN_NAME"
