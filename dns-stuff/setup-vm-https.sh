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

# Optimize Nginx for high concurrency
echo "⚙️  Optimizing Nginx configuration for 300+ concurrent users..."
sudo tee /etc/nginx/nginx.conf > /dev/null <<EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;

# Optimize for high concurrency
worker_rlimit_nofile 65535;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # MIME types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Gzip compression for better performance
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # Logging
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for" '
                    'rt=\$request_time uct="\$upstream_connect_time" '
                    'uht="\$upstream_header_time" urt="\$upstream_response_time"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;
    
    # Include site configurations
    include /etc/nginx/sites-enabled/*;
}
EOF

# Create optimized site configuration
sudo tee /etc/nginx/sites-available/llmdemo > /dev/null <<EOF
# Upstream for load balancing (future-proofing)
upstream flask_app {
    server localhost:5000;
    keepalive 32;
}

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
    
    # SSL optimization
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_prefer_server_ciphers on;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Rate limiting for demo protection
    limit_req_zone \$binary_remote_addr zone=api:10m rate=30r/m;
    limit_req_zone \$binary_remote_addr zone=general:10m rate=60r/m;
    
    # Static files (if any)
    location /static/ {
        alias /app/static/;
        expires 1h;
        add_header Cache-Control "public, immutable";
    }
    
    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api burst=10 nodelay;
        
        proxy_pass http://flask_app;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
        
        # Optimized timeouts for API calls
        proxy_connect_timeout 10s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer optimization
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }
    
    # All other requests
    location / {
        limit_req zone=general burst=20 nodelay;
        
        proxy_pass http://flask_app;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
        
        # Standard timeouts
        proxy_connect_timeout 10s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        
        # Buffer optimization
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
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

# Test the Docker container connection
echo "🧪 Testing Docker container connection..."
if curl -s http://localhost:5000/menu | grep -q "LLM Demo"; then
    echo "✅ Docker container is accessible on localhost:5000"
else
    echo "❌ Docker container not accessible. Is docker compose running?"
    echo "   Run: docker compose ps"
    exit 1
fi

# Test the HTTPS setup
echo "🧪 Testing HTTPS setup..."
sleep 5

if curl -k -s https://localhost | grep -q "LLM Demo"; then
    echo "✅ HTTPS setup successful!"
else
    echo "⚠️  HTTPS setup may need manual verification"
    echo "   Check nginx logs: sudo tail -f /var/log/nginx/error.log"
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
