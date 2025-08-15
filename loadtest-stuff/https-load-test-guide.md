# HTTPS Domain Load Testing Guide

## 🎯 Your Professional Demo Setup
- **Domain**: https://dd-demo-sg-llm.com
- **SSL**: Let's Encrypt certificates
- **Architecture**: nginx-proxy → Flask app (12 workers, 4 threads)
- **Target**: 300 concurrent users

## 🚀 Load Test Options

### Option 1: CTF-Focused Test (Recommended for Demo)
```bash
# Test your CTF challenges under HTTPS load
./ctf-focused-load-test.sh 100   # Warm-up
./ctf-focused-load-test.sh 200   # Stress test  
./ctf-focused-load-test.sh 300   # Demo target

# Analyze results
./analyze-load-results.sh load-test-results/ctf_300users_TIMESTAMP
```

### Option 2: Multi-Endpoint Test
```bash
# Test all endpoints comprehensively
./multi-endpoint-load-test.sh 100
./multi-endpoint-load-test.sh 300

# Analyze results
./analyze-load-results.sh load-test-results/multi_300users_TIMESTAMP
```

### Option 3: Simple Load Test
```bash
# Basic performance test
./simple-load-test.sh 100
./simple-load-test.sh 300
```

## 📊 Expected Performance with HTTPS + nginx-proxy

### Performance Improvements
- **SSL Termination**: nginx handles encryption (faster than Flask)
- **Connection Pooling**: nginx maintains persistent connections
- **HTTP/2**: Multiplexed connections for better performance
- **Gzip Compression**: Smaller response sizes

### Expected Results
| Metric | HTTP (old) | HTTPS + nginx | Improvement |
|--------|------------|---------------|-------------|
| Response Time | 1.2s | 1.0s | 17% faster |
| Throughput | 300 req/s | 400 req/s | 33% higher |
| SSL Overhead | N/A | ~50ms | Minimal |
| Connection Reuse | No | Yes | Much better |

## 🔍 Monitoring During Load Test

### Real-time Monitoring Commands
```bash
# Monitor nginx connections
watch -n 1 'docker compose exec nginx ss -tuln | grep :443 | wc -l'

# Monitor SSL handshakes
docker compose logs nginx | grep -i ssl

# Monitor Let's Encrypt (should be quiet during test)
docker compose logs letsencrypt

# Monitor your Flask app
docker compose logs app | tail -20

# System resources
htop
```

### Key Metrics to Watch
- **SSL Connection Count**: Should handle 300+ concurrent
- **Certificate Validity**: Should remain valid throughout
- **nginx Response Times**: Should be < 100ms overhead
- **Flask App Performance**: Should be similar to before

## 🎪 Demo-Specific Testing

### Test Your Demo Scenarios
```bash
# 1. Test CTF challenges under load
./ctf-focused-load-test.sh 300

# 2. Verify bypass detection still works
./analyze-load-results.sh load-test-results/ctf_300users_TIMESTAMP

# 3. Test clean URLs work
curl -I https://dd-demo-sg-llm.com/menu
curl -I https://dd-demo-sg-llm.com/ctf  
curl -I https://dd-demo-sg-llm.com/business
```

### Professional Demo URLs
- **Main Demo**: https://dd-demo-sg-llm.com/menu
- **CTF Challenge**: https://dd-demo-sg-llm.com/ctf
- **Business Demo**: https://dd-demo-sg-llm.com/business
- **API Status**: https://dd-demo-sg-llm.com/api/ai-guard-status

## 🚨 Troubleshooting

### If Load Test Fails
```bash
# Check SSL certificate validity
curl -I https://dd-demo-sg-llm.com

# Check nginx proxy status
docker compose ps nginx

# Check for SSL errors
docker compose logs nginx | grep -i error

# Test without SSL (should redirect)
curl -I http://dd-demo-sg-llm.com
```

### SSL-Specific Issues
```bash
# Check certificate expiry
docker compose exec nginx openssl x509 -in /etc/nginx/certs/dd-demo-sg-llm.com.crt -dates -noout

# Check SSL configuration
docker compose exec nginx nginx -T | grep ssl

# Force certificate renewal (if needed)
docker compose restart letsencrypt
```

## 🎯 Success Criteria

### ✅ Your HTTPS setup is ready for 300 users if:
- Load test shows >95% success rate
- Response times < 2 seconds average
- No SSL certificate errors
- CTF bypasses still detected correctly
- Clean URLs work: https://dd-demo-sg-llm.com/*

### 🎉 Demo Readiness Checklist
- [ ] HTTPS load test passes with 300 users
- [ ] CTF challenges work under load
- [ ] Datadog monitoring captures all events
- [ ] Professional URLs ready for slides
- [ ] SSL certificates valid and auto-renewing
