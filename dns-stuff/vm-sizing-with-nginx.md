# VM Sizing Analysis with Nginx

## Current Setup (n1-standard-8)
- **8 vCPU, 30GB RAM**
- **Cost**: ~$200/month

## Resource Breakdown

### Without Nginx (Current)
| Component | RAM Usage | CPU Usage |
|-----------|-----------|-----------|
| Gunicorn (12 workers) | ~2.4GB | ~4-6 cores |
| Docker overhead | ~500MB | ~0.5 cores |
| Datadog agent | ~200MB | ~0.2 cores |
| OS + buffers | ~1GB | ~0.5 cores |
| **Total** | **~4.1GB** | **~5.2 cores** |

### With Nginx Added
| Component | RAM Usage | CPU Usage |
|-----------|-----------|-----------|
| Gunicorn (12 workers) | ~2.4GB | ~4-6 cores |
| **Nginx** | **~50MB** | **~0.3 cores** |
| Docker overhead | ~500MB | ~0.5 cores |
| Datadog agent | ~200MB | ~0.2 cores |
| OS + buffers | ~1GB | ~0.5 cores |
| **Total** | **~4.15GB** | **~5.5 cores** |

## Performance Under 300 Concurrent Users

### Load Distribution
- **Nginx**: Handles all incoming HTTPS connections
- **Connection pooling**: Nginx maintains ~50 connections to Flask
- **Request queuing**: Nginx buffers requests during spikes

### Expected Performance
- **Memory usage**: ~4.2GB / 30GB = **14% utilization** ✅
- **CPU usage**: ~5.5 cores / 8 cores = **69% utilization** ✅
- **Network**: Nginx improves throughput with compression

## Sizing Recommendations

### ✅ Current VM (n1-standard-8) - PERFECT
- **Headroom**: 4.5GB RAM, 2.5 CPU cores available
- **Performance**: Will handle 300+ users easily
- **Cost**: Reasonable for demo

### 💰 Cost Optimization Options

#### Option 1: Downsize to n1-standard-4 (4 vCPU, 15GB RAM)
- **Cost**: ~$100/month (50% savings)
- **Performance**: Still handles 300 users
- **Risk**: Less headroom for spikes

#### Option 2: Keep n1-standard-8 (Recommended)
- **Cost**: ~$200/month
- **Performance**: Excellent with plenty of headroom
- **Risk**: Minimal - perfect for demo

## Load Test Expectations with Nginx

### Performance Improvements
- **Response times**: 10-20% faster (static files)
- **Throughput**: 15-25% higher (connection pooling)
- **Reliability**: Better handling of connection spikes
- **SSL overhead**: Nginx handles SSL termination efficiently

### Bottleneck Analysis
1. **Database (SQLite)**: Still the main bottleneck
2. **OpenAI API calls**: External dependency
3. **CPU**: Plenty of headroom
4. **Memory**: Plenty of headroom
5. **Network**: Nginx improves this

## Monitoring Recommendations

### Key Metrics to Watch
```bash
# CPU usage
htop

# Memory usage
free -h

# Nginx connections
sudo nginx -T | grep worker_connections

# Docker stats
docker stats

# Nginx access logs
sudo tail -f /var/log/nginx/access.log
```

### Datadog Dashboards
- **Nginx metrics**: Connection count, response times
- **System metrics**: CPU, memory, disk I/O
- **Application metrics**: Flask response times, error rates

## Conclusion

✅ **Your n1-standard-8 VM is PERFECT for 300 users with Nginx**
- Nginx adds minimal overhead (~50MB RAM, 0.3 CPU)
- Performance actually improves due to Nginx optimizations
- Plenty of headroom for traffic spikes
- Professional HTTPS setup without complexity
