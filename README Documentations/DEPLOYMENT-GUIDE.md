# 🚀 Production Deployment Guide

This guide covers deploying the LLM Demo application to handle **300+ concurrent users** on Google Cloud Platform with full HTTPS, monitoring, and professional domain setup.

## 🏗️ Production Architecture Options

### **Option 1: Multi-VM Load Balanced (RECOMMENDED)**
- **Platform**: Google Cloud Platform (GCP Compute Engine)
- **Load Balancer**: Google Cloud Load Balancer
- **VM Instances**: 10x n1-standard-8 (8 vCPUs, 30GB RAM each)
- **Operating System**: Container-Optimized OS (COS)
- **Domain**: prod.dd-demo-sg-llm.com (Google-managed SSL)
- **Capacity**: 3,500+ concurrent users (tested at 350 users)
- **Deployment**: Automated with `deploy-to-vms.sh`

### **Option 2: Single VM (Legacy)**
- **VM Instance**: 1x n1-standard-8 (8 vCPUs, 30GB RAM)
- **Domain**: dd-demo-sg-llm.com (Let's Encrypt SSL)
- **Capacity**: 350+ concurrent users tested and verified

## 📋 Prerequisites

### Required Tools
- Google Cloud SDK installed and authenticated
- Docker installed locally (for testing)
- Git access to the repository

### Required API Keys
Create a `.env` file with:
```bash
# OpenAI API Key - required for LLM functionality
OPENAI_API_KEY=sk-proj-xxxxxx

# Datadog API Key - required for monitoring and tracing
DD_API_KEY=xxxxxxxx
DD_APP_KEY=xxxxxxx

# Eppo API Key - required for feature flag capabilities (optional)
EPPO_API_KEY=xxxxxxx
```

### GCP Setup
1. **Enable APIs**:
   ```bash
   gcloud services enable compute.googleapis.com
   gcloud services enable dns.googleapis.com
   ```

2. **Set Project**:
   ```bash
   gcloud config set project YOUR_PROJECT_ID
   ```

## 🚀 Deployment Steps

### **NEW: Multi-VM Load Balanced Deployment**

#### Quick Setup (Recommended)
```bash
# 1. Clone repository
git clone YOUR_REPO_URL
cd llmdemo-prod

# 2. Create .env file with API keys
cp .env.example .env
# Edit .env with your API keys

# 3. Deploy all VMs and load balancer (automated)
./deploy-to-vms.sh

# 4. Choose deployment method:
# 1) Sequential (safer, ask before each VM)
# 2) Parallel (faster, all VMs at once)
# 3) Health check only
```

#### Manual Multi-VM Setup
If you prefer manual control, follow these steps:

### Step 1: Deploy VM Infrastructure

```bash
# Clone repository to your local machine
git clone YOUR_REPO_URL
cd llmdemo-prod

# Deploy VM with optimized configuration
gcloud compute instances create llmdemo-vm \
    --zone=us-central1-a \
    --machine-type=n1-standard-8 \
    --image-family=cos-stable \
    --image-project=cos-cloud \
    --boot-disk-size=50GB \
    --boot-disk-type=pd-ssd \
    --tags=http-server,https-server \
    --labels=please_keep_my_resource=true \
    --metadata=startup-script='#!/bin/bash
      # Install docker-compose plugin
        $ sudo curl -sSL \
        https://github.com/docker/compose/releases/download/v2.23.3/docker-compose-linux-x86_64 \
        -o /var/lib/google/docker-compose
        $ sudo chmod o+x /var/lib/google/docker-compose
        $ mkdir -p ~/.docker/cli-plugins
        $ ln -sf /var/lib/google/docker-compose \
        ~/.docker/cli-plugins/docker-compose
        $ docker compose version

# Create firewall rules
gcloud compute firewall-rules create allow-llmdemo-http \
    --allow tcp:80,tcp:443,tcp:5000 \
    --source-ranges 0.0.0.0/0 \
    --target-tags http-server,https-server
```

### Step 2: Configure Domain and DNS

1. **Register Domain** (if not done):
   - Go to [Google Domains](https://domains.google.com)
   - Register `your-demo-domain.com`

2. **Set up Cloud DNS**:
   ```bash
   # Create DNS zone
   gcloud dns managed-zones create llmdemo-zone \
       --description="LLM Demo DNS Zone" \
       --dns-name=dd-demo-sg-llm.com

   # Get VM external IP
   VM_IP=$(gcloud compute instances describe llmdemo-vm \
       --zone=us-central1-a \
       --format="get(networkInterfaces[0].accessConfigs[0].natIP)")

   # Create A record
   gcloud dns record-sets transaction start --zone=llmdemo-zone
   gcloud dns record-sets transaction add $VM_IP \
       --name=dd-demo-sg-llm.com. \
       --ttl=300 \
       --type=A \
       --zone=llmdemo-zone
   gcloud dns record-sets transaction add $VM_IP \
       --name=www.dd-demo-sg-llm.com. \
       --ttl=300 \
       --type=A \
       --zone=llmdemo-zone
   gcloud dns record-sets transaction execute --zone=llmdemo-zone
   ```

### Step 3: Deploy Application

```bash
# SSH into VM
gcloud compute ssh llmdemo-vm --zone=us-central1-a

# On the VM, clone repository
git clone YOUR_REPO_URL
cd llmdemo-prod

# Create .env file with your API keys
vi .env
# (Add your API keys as shown in prerequisites)

# Start the application stack
docker compose up -d

# Verify all containers are running
docker compose ps
```

### Step 4: Verify HTTPS Setup

```bash
# Test HTTP (should redirect to HTTPS)
curl -I http://dd-demo-sg-llm.com

# Test HTTPS (should return 200)
curl -I https://dd-demo-sg-llm.com

# Test application endpoints
curl https://dd-demo-sg-llm.com/menu
curl https://dd-demo-sg-llm.com/ctf
curl https://dd-demo-sg-llm.com/business
```

## 🐳 Docker Compose Stack

The production stack includes:

```yaml
services:
  nginx:          # nginx-proxy for reverse proxy and SSL termination
  letsencrypt:    # acme-companion for automatic SSL certificates
  app:            # Flask application with Gunicorn (12 workers)
  datadog:        # Datadog agent for monitoring
```

### Container Configuration

#### nginx-proxy
- **Ports**: 80, 443
- **Function**: HTTPS termination, reverse proxy
- **SSL**: Automatic Let's Encrypt integration
- **Performance**: Connection pooling, HTTP/2, gzip compression

#### Flask Application
- **Server**: Gunicorn with 12 sync workers + 4 threads each
- **Capacity**: 48 concurrent requests per instance
- **Database**: SQLite with WAL mode + connection pooling
- **Monitoring**: Full Datadog APM integration

#### Datadog Agent
- **APM**: Application performance monitoring
- **LLM Observability**: OpenAI API call tracking
- **Custom Metrics**: Security events, user interactions
- **Ports**: 8126 (APM), 4317-4318 (OTLP)

## 📊 Performance Optimization

### Current Performance Characteristics
- **Concurrent Users**: 300+ tested capacity
- **Response Time**: < 2s for 95% of requests
- **Throughput**: 400+ requests/second
- **Memory Usage**: ~4.2GB / 30GB (14% utilization)
- **CPU Usage**: ~5.5 cores / 8 cores (69% utilization)

### Database Optimization
- **SQLite WAL Mode**: Concurrent reads during writes
- **Connection Pooling**: Reduced connection overhead
- **Performance Pragmas**: Optimized for read-heavy workloads
- **Expected Throughput**: 1000+ queries/second

### Gunicorn Configuration
```python
# Optimized for I/O bound workloads with LLM API calls
workers = 12              # CPU cores * 1.5
worker_class = "sync"     # Compatible with Datadog tracing
threads = 4               # Per worker thread pool
max_requests = 1000       # Worker recycling
preload_app = True        # Memory optimization
```

## 🔍 Monitoring & Health Checks

### Health Check Endpoints
- **Application**: `https://dd-demo-sg-llm.com/menu`
- **API Status**: `https://dd-demo-sg-llm.com/api/rag-status`

### Datadog Monitoring
- **APM Traces**: Full request lifecycle with distributed tracing
- **RUM (Real User Monitoring)**: Frontend user experience tracking
- **Custom Metrics**: Business logic monitoring
- **CTF Winner Tracking**: Real-time challenge completion analytics
- **Alerts**: Performance degradation detection
- **Dashboards**: Real-time system metrics
- **Trace Correlation**: End-to-end visibility from browser to backend

### Key Metrics to Monitor
1. **Response Time**: P50, P95, P99 percentiles
2. **Error Rate**: 4xx, 5xx HTTP status codes
3. **Throughput**: Requests per second
4. **Database Performance**: Query execution times
5. **LLM API**: OpenAI response times and costs

## 🧪 Load Testing

### Production Load Tests

#### **Multi-VM Load Testing**
```bash
# Test load balanced setup (350 concurrent users)
./test-scripts/security-stress-test.sh  # Updated for 350 users
./test-scripts/ctf-stress-test.sh       # Updated for 350 users

# Deploy updates to all VMs
./deploy-to-vms.sh
```

#### **Single VM Load Testing**
```bash
# SSH into VM for testing
gcloud compute ssh llmdemo-vm --zone=us-central1-a

# Run security-focused stress test (350 users)
cd llmdemo-prod
./test-scripts/security-stress-test.sh

# Run CTF-focused stress test (350 users)
./test-scripts/ctf-stress-test.sh

# Run legacy comprehensive test
./test-scripts/ctf-focused-load-test.sh 300

# Analyze results
./test-scripts/analyze-load-results.sh load-test-results/security_300users_TIMESTAMP
```

### Expected Load Test Results
- **Success Rate**: >95%
- **Average Response Time**: <2s
- **Peak Throughput**: 400+ req/s
- **Memory Usage**: Stable under load
- **CPU Usage**: 60-80% during peak load

### **Latest Verified Results** (300 concurrent users)
- **Total Requests**: 6,062
- **Success Rate**: 99.8% (6,052 successful requests)
- **Security Events**: 2,035 detected (33.6% of requests)
- **Attack Success Rate**: 95.2% (demonstrates app vulnerability for WAF demo)
- **Average Response Time**: 4.82ms
- **Security Evaluation Time**: <5ms average

## 🔒 Security Configuration

### SSL/TLS Setup
- **Provider**: Let's Encrypt (free, automated)
- **Renewal**: Automatic every 90 days
- **Protocols**: TLS 1.2+
- **Cipher Suites**: Modern, secure configurations

### Firewall Configuration
```bash
# Only necessary ports open
Port 80:   HTTP (redirects to HTTPS)
Port 443:  HTTPS (main application)
Port 5000: Direct app access (for debugging)
```

### Container Security
- **Isolation**: Docker network segmentation
- **Secrets**: Environment variable management
- **Updates**: Regular container image updates

## 🛠️ Maintenance & Updates

### Regular Maintenance Tasks
```bash
# Update application code
cd llmdemo-prod
git pull
docker compose restart app

# Update container images
docker compose pull
docker compose up -d

# Check SSL certificate status
docker compose logs letsencrypt

# Monitor system resources
docker stats
htop
```

### SSL Certificate Management
- **Automatic Renewal**: acme-companion handles this
- **Manual Renewal** (if needed):
  ```bash
  docker compose restart letsencrypt
  ```
- **Certificate Status**:
  ```bash
  docker compose exec nginx openssl x509 -in /etc/nginx/certs/dd-demo-sg-llm.com.crt -dates -noout
  ```

### Troubleshooting

#### Application Issues
```bash
# Check application logs
docker compose logs app

# Check nginx proxy logs
docker compose logs nginx

# Check SSL certificate logs
docker compose logs letsencrypt

# Restart specific service
docker compose restart app
```

#### Performance Issues
```bash
# Monitor resource usage
htop
docker stats

# Check database connections
docker compose exec app python -c "from src.database import get_connection_pool_status; print(get_connection_pool_status())"

# Monitor request patterns
docker compose logs nginx | tail -100
```

## 💰 Cost Analysis

### Monthly Costs (Estimated)
- **VM Instance (n1-standard-8)**: ~$200/month
- **Persistent Disk (50GB SSD)**: ~$10/month
- **Network Egress**: ~$10-20/month (depending on traffic)
- **DNS Queries**: ~$1/month
- **Domain Registration**: ~$12/year

**Total**: ~$220-230/month for production-ready setup

### Cost Optimization Options
1. **Downsize VM**: n1-standard-4 for ~$100/month (still handles 300 users)
2. **Preemptible Instance**: 60-80% cost savings (not recommended for demos)
3. **Regional Persistent Disk**: Slight cost reduction
4. **Committed Use Discounts**: 20-30% savings for long-term use

## 🎯 Demo Day Checklist

### Pre-Demo (1 week before)
- [ ] Deploy to production environment
- [ ] Load test with 300+ concurrent users
- [ ] Verify all API keys and secrets
- [ ] Test all application features
- [ ] Set up monitoring dashboards
- [ ] Verify SSL certificates are valid

### Demo Day (morning of)
- [ ] Verify application is running: `docker compose ps`
- [ ] Test all endpoints: CTF, Business, Menu
- [ ] Check SSL certificate status
- [ ] Verify Datadog monitoring is active
- [ ] Test load balancing and performance
- [ ] Have troubleshooting commands ready

### During Demo
- [ ] Monitor real-time metrics in Datadog
- [ ] Watch application logs for errors
- [ ] Keep deployment commands ready
- [ ] Monitor response times and error rates

## 📞 Support & Troubleshooting

### Common Issues and Solutions

#### SSL Certificate Issues
```bash
# Check certificate validity
curl -I https://dd-demo-sg-llm.com

# Force certificate renewal
docker compose restart letsencrypt

# Check Let's Encrypt logs
docker compose logs letsencrypt
```

#### Application Performance Issues
```bash
# Check resource usage
docker stats

# Restart application
docker compose restart app

# Check database performance
docker compose logs app | grep -i database
```

#### DNS Issues
```bash
# Check DNS resolution
nslookup dd-demo-sg-llm.com

# Verify A records
dig dd-demo-sg-llm.com A
```

### Emergency Procedures
1. **Application Down**: `docker compose restart app`
2. **SSL Issues**: `docker compose restart letsencrypt`
3. **Complete Restart**: `docker compose down && docker compose up -d`
4. **Rollback**: `git checkout PREVIOUS_COMMIT && docker compose restart app`

---

## 🎉 Success Criteria

### **Multi-VM Load Balanced Setup**
Your deployment is successful when:
- ✅ HTTPS domain accessible: https://prod.dd-demo-sg-llm.com
- ✅ All 10 VMs healthy and receiving traffic
- ✅ Load test passes with 350+ users
- ✅ Datadog APM + RUM monitoring active
- ✅ CTF winner tracking working in Datadog
- ✅ Response times 2-3s under 350-user load
- ✅ Deployment script working: `./deploy-to-vms.sh`

### **Single VM Setup**
Your deployment is successful when:
- ✅ HTTPS domain accessible: https://dd-demo-sg-llm.com
- ✅ All application features working
- ✅ Load test passes with 350+ users
- ✅ Datadog monitoring active
- ✅ SSL certificates auto-renewing
- ✅ Response times < 2s under load

**Your application is now ready for enterprise-scale demonstrations!** 🚀

### **NEW: CTF Winner Tracking Verification**
```bash
# Verify RUM tracking is working
# 1. Complete a CTF challenge
# 2. Check Datadog RUM for events:
@type:action @action.name:ctf_challenge_won

# Should show winner username and completion details
```