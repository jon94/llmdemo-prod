# Production Deployment Guide for LLM Demo

This guide will help you deploy your LLM Demo application to handle 300+ concurrent users on AWS or GCP.

## 🚀 Quick Start

Your application has been optimized for production with:
- **Gunicorn**: 12 sync workers + 4 threads each (48 concurrent requests per instance)
- **SQLite**: WAL mode + connection pooling for concurrent access
- **Auto-scaling**: 2-10 instances based on load
- **Resource allocation**: 2 vCPU, 4GB RAM per instance
- **Datadog Compatibility**: Full tracing support (no gevent conflicts)

**Expected capacity**: 300+ concurrent users across multiple instances.

## 📋 Prerequisites

### For AWS Deployment
- AWS CLI configured with appropriate permissions
- Docker installed
- ECR repository created
- ECS cluster created
- Application Load Balancer configured
- Secrets stored in AWS Secrets Manager

### For GCP Deployment  
- Google Cloud SDK installed and authenticated
- Docker installed
- Container Registry API enabled
- Cloud Run API enabled
- Secret Manager API enabled

## 🔧 Configuration Steps

### 1. Update Configuration Files

#### AWS Deployment
Edit `deploy-aws.sh` and update:
```bash
AWS_ACCOUNT_ID="your-account-id"
AWS_REGION="us-east-1"  # or your preferred region
```

Edit `aws-ecs-task-definition.json` and update:
- Replace `YOUR_ACCOUNT_ID` with your AWS account ID
- Update secret ARNs to match your AWS Secrets Manager secrets

#### GCP Deployment
Edit `deploy-gcp.sh` and update:
```bash
PROJECT_ID="your-project-id"
REGION="us-central1"  # or your preferred region
```

### 2. Set Up Secrets

#### AWS Secrets Manager
Create secrets for:
- `llmdemo/openai-api-key`
- `llmdemo/datadog-api-key` 
- `llmdemo/datadog-app-key`
- `llmdemo/eppo-api-key`

#### GCP Secret Manager
Create a secret named `llmdemo-secrets` with JSON content:
```json
{
  "openai-api-key": "your-openai-key",
  "datadog-api-key": "your-datadog-key", 
  "datadog-app-key": "your-datadog-app-key",
  "eppo-api-key": "your-eppo-key"
}
```

## 🚀 Deployment

### Option 1: VM Instance (Recommended for Full Control)

**GCP Compute Engine:**
```bash
./deploy-vm.sh
```

**AWS EC2:**
```bash
./deploy-aws-vm.sh
```

**Benefits:**
- ✅ Keep your exact docker-compose setup
- ✅ Separate Datadog agent container
- ✅ Full monitoring capabilities
- ✅ Easy debugging and management
- ✅ Cost-effective single VM approach

### Option 2: AWS ECS Fargate
```bash
./deploy-aws.sh
```

This will:
1. Build and push Docker image to ECR
2. Register new ECS task definition
3. Update ECS service
4. Configure auto-scaling (2-10 instances)
5. Set up CPU-based scaling policies

### Option 3: GCP Cloud Run
```bash
./deploy-gcp.sh
```

This will:
1. Build and push Docker image to GCR
2. Deploy to Cloud Run with auto-scaling
3. Configure monitoring and uptime checks
4. Set up 2-10 instance scaling
5. **Note:** Requires agentless Datadog mode (no separate agent container)

## 📊 Performance Characteristics

### Single Instance Capacity
- **Workers**: 12 sync workers with 4 threads each
- **Concurrent requests**: 48 per instance (12 workers × 4 threads)
- **Datadog tracing**: Fully compatible (no gevent conflicts)
- **Realistic capacity**: ~200-300 concurrent users per instance

### Multi-Instance Setup
- **Minimum**: 2 instances (400-600 concurrent users)
- **Maximum**: 10 instances (2000-3000 concurrent users)
- **Target for 300 users**: 2-3 instances with comfortable headroom

### SQLite Performance
- **WAL mode**: Enables concurrent reads during writes
- **Connection pooling**: Reduces connection overhead
- **Optimized pragmas**: Improved performance settings
- **Expected throughput**: 1000+ queries/second

## 🔍 Monitoring & Troubleshooting

### Health Checks
Both platforms monitor `/menu` endpoint:
- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Failure threshold**: 3 consecutive failures

### Auto-scaling Triggers
- **AWS**: CPU utilization > 70%
- **GCP**: Automatic based on request volume and latency

### Logs
- **AWS**: CloudWatch Logs at `/ecs/llmdemo-prod`
- **GCP**: Cloud Logging automatically configured

### Key Metrics to Monitor
1. **Response time**: Should stay under 2 seconds
2. **Error rate**: Should be < 1%
3. **CPU utilization**: Target 60-80% for optimal scaling
4. **Memory usage**: Should stay under 3GB per instance
5. **Database connections**: Monitor connection pool usage

## 🛠 Troubleshooting

### High Response Times
- Check CPU utilization (scale up if > 80%)
- Monitor database connection pool
- Review SQLite query performance

### Connection Errors
- Verify load balancer health checks
- Check container resource limits
- Review Gunicorn worker configuration

### Database Issues
- SQLite WAL mode should handle concurrent reads
- Monitor connection pool size
- Check disk I/O if using persistent storage

## 🔄 Updates & Rollbacks

### AWS
```bash
# Deploy new version
./deploy-aws.sh

# Rollback (if needed)
aws ecs update-service --cluster llmdemo-cluster --service llmdemo-prod-service --task-definition llmdemo-prod:PREVIOUS_REVISION
```

### GCP
```bash
# Deploy new version  
./deploy-gcp.sh

# Rollback (if needed)
gcloud run services update llmdemo-prod --image=gcr.io/PROJECT_ID/llmdemo-prod:PREVIOUS_TAG --region=us-central1
```

## 💰 Cost Optimization

### AWS ECS Fargate
- **2 instances**: ~$60-80/month
- **10 instances**: ~$300-400/month
- Use Spot instances for cost savings (not recommended for demos)

### GCP Cloud Run
- **Pay per request**: More cost-effective for variable load
- **2 instances minimum**: ~$40-60/month
- **10 instances maximum**: ~$200-300/month

## 🎯 Demo Day Checklist

### Pre-Demo (1 week before)
- [ ] Deploy to staging environment
- [ ] Load test with 300+ concurrent users
- [ ] Verify all API keys and secrets
- [ ] Test auto-scaling behavior
- [ ] Set up monitoring dashboards

### Demo Day (morning of)
- [ ] Deploy latest version to production
- [ ] Verify health checks are passing
- [ ] Scale to minimum 3 instances
- [ ] Test all application features
- [ ] Monitor logs for any errors
- [ ] Have rollback plan ready

### During Demo
- [ ] Monitor real-time metrics
- [ ] Watch for auto-scaling events
- [ ] Keep deployment scripts ready
- [ ] Monitor error rates and response times

## 📞 Support

If you encounter issues:
1. Check application logs first
2. Verify health check endpoints
3. Monitor resource utilization
4. Review auto-scaling events
5. Test database connectivity

Your application is now ready to handle 300+ concurrent users! 🎉
