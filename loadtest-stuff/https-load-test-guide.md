# 🚀 HTTPS Load Testing Guide

## 🎯 Production Setup Overview
- **Domain**: https://dd-demo-sg-llm.com
- **SSL**: Let's Encrypt certificates with nginx-proxy
- **Architecture**: nginx-proxy → Flask app (12 workers, 4 threads each)
- **Target Capacity**: 300+ concurrent users
- **VM**: GCP n1-standard-8 (8 vCPUs, 30GB RAM)

## 🧪 Load Testing Options

### Option 1: CTF-Focused Test (Recommended for Security Demos)
```bash
# Test security challenges under production load
./test-scripts/ctf-focused-load-test.sh 100   # Warm-up test
./test-scripts/ctf-focused-load-test.sh 200   # Stress test  
./test-scripts/ctf-focused-load-test.sh 300   # Full demo capacity

# Analyze results with bypass detection
./test-scripts/analyze-load-results.sh load-test-results/ctf_300users_TIMESTAMP
```

**What it tests:**
- Guardrail CTF challenges under load
- Prompt injection attempts
- Secret extraction scenarios
- Security bypass detection
- WAF protection effectiveness

### Option 2: Multi-Endpoint Test (Comprehensive Coverage)
```bash
# Test all application endpoints
./test-scripts/multi-endpoint-load-test.sh 100
./test-scripts/multi-endpoint-load-test.sh 300

# Analyze comprehensive results
./test-scripts/analyze-load-results.sh load-test-results/multi_300users_TIMESTAMP
```

**What it tests:**
- All UI endpoints (/menu, /ctf, /business)
- API endpoints (/api/security, /api/rag-status)
- Database queries (profile, orders)
- RAG system performance
- Overall system stability

### Option 3: Simple Load Test (Basic Performance)
```bash
# Basic endpoint performance test
./test-scripts/simple-load-test.sh 100
./test-scripts/simple-load-test.sh 300
```

**What it tests:**
- Basic HTTP/HTTPS performance
- Response time consistency
- Server stability under load

## 📊 Expected Performance with HTTPS + nginx-proxy

### Performance Improvements from nginx-proxy
- **SSL Termination**: nginx handles encryption (offloads Flask)
- **Connection Pooling**: Persistent connections to backend
- **HTTP/2 Support**: Multiplexed connections
- **Gzip Compression**: Reduced response sizes
- **Static File Serving**: Direct nginx serving (if applicable)

### Benchmark Comparison
| Metric | Direct Flask | nginx-proxy + Flask | Improvement |
|--------|-------------|-------------------|-------------|
| Response Time | 1.2s | 1.0s | 17% faster |
| Throughput | 300 req/s | 400 req/s | 33% higher |
| SSL Overhead | N/A | ~50ms | Minimal impact |
| Connection Reuse | Limited | Excellent | Much better |
| Memory Usage | Higher | Lower | nginx efficiency |

### Expected Load Test Results (300 Users)
- **Success Rate**: >95%
- **Average Response Time**: <2s
- **P95 Response Time**: <3s
- **Peak Throughput**: 400+ req/s
- **Error Rate**: <1%
- **SSL Handshake Time**: <100ms

## 🔍 Real-time Monitoring During Load Tests

### Container Monitoring Commands
```bash
# Monitor nginx connections and performance
docker compose exec nginx ss -tuln | grep :443 | wc -l

# Watch nginx access logs in real-time
docker compose logs -f nginx

# Monitor SSL certificate status
docker compose logs letsencrypt | grep -i error

# Monitor Flask application performance
docker compose logs -f app | grep -E "(ERROR|WARNING|INFO)"

# System resource monitoring
docker stats
htop
```

### Key Metrics to Watch

#### nginx-proxy Metrics
- **Active Connections**: Should handle 300+ concurrent
- **SSL Handshakes**: Should complete in <100ms
- **Response Times**: nginx overhead should be <50ms
- **Error Rates**: Should be minimal

#### Application Metrics
- **Gunicorn Workers**: All 12 workers should be active
- **Database Connections**: Connection pool should be stable
- **Memory Usage**: Should stay under 4GB
- **CPU Usage**: Should peak around 60-80%

#### SSL/TLS Metrics
- **Certificate Validity**: Should remain valid throughout test
- **TLS Version**: Should use TLS 1.2+
- **Cipher Suites**: Should use modern, secure ciphers

## 🎪 Demo-Specific Load Testing

### Security Demo Load Test Flow
```bash
# 1. Warm up the system
./test-scripts/simple-load-test.sh 50

# 2. Test CTF challenges under load
./test-scripts/ctf-focused-load-test.sh 300

# 3. Verify security features still work
./test-scripts/analyze-load-results.sh load-test-results/ctf_300users_TIMESTAMP

# 4. Check for successful bypasses (should be detected)
grep -i "bypass\|secret" load-test-results/ctf_300users_TIMESTAMP/ctf_successes.csv
```

### Professional Demo URLs
Test these URLs during load testing:
- **Main Menu**: https://dd-demo-sg-llm.com/menu
- **CTF Challenges**: https://dd-demo-sg-llm.com/ctf
- **Business Chat**: https://dd-demo-sg-llm.com/business
- **API Health**: https://dd-demo-sg-llm.com/api/rag-status

### Load Test Validation Commands
```bash
# Test SSL certificate validity
curl -I https://dd-demo-sg-llm.com

# Test HTTP to HTTPS redirect
curl -I http://dd-demo-sg-llm.com

# Test all main endpoints
for endpoint in menu ctf business; do
  echo "Testing /$endpoint"
  curl -I https://dd-demo-sg-llm.com/$endpoint
done

# Test API endpoints
curl -s https://dd-demo-sg-llm.com/api/rag-status | jq .
```

## 🚨 Troubleshooting Load Test Issues

### SSL/HTTPS Issues
```bash
# Check SSL certificate status
openssl s_client -connect dd-demo-sg-llm.com:443 -servername dd-demo-sg-llm.com

# Check nginx SSL configuration
docker compose exec nginx nginx -T | grep ssl

# Check Let's Encrypt certificate details
docker compose exec nginx openssl x509 -in /etc/nginx/certs/dd-demo-sg-llm.com.crt -text -noout

# Force SSL certificate renewal if needed
docker compose restart letsencrypt
```

### Performance Issues
```bash
# Check if nginx is the bottleneck
docker compose logs nginx | grep -i error

# Check if Flask app is the bottleneck
docker compose logs app | grep -E "(timeout|error|slow)"

# Check database performance
docker compose logs app | grep -i database

# Monitor system resources
iostat -x 1
free -h
```

### Connection Issues
```bash
# Check nginx upstream connections
docker compose exec nginx ss -tuln | grep :5000

# Check Flask app is responding
curl -I http://localhost:5000/menu

# Check Docker network connectivity
docker compose exec nginx ping app
```

## 📈 Load Test Analysis

### Success Criteria
Your HTTPS setup is ready for 300+ users if:
- ✅ Load test shows >95% success rate
- ✅ Average response times <2 seconds
- ✅ No SSL certificate errors during test
- ✅ nginx-proxy handles connections efficiently
- ✅ All security features work under load
- ✅ Datadog captures all performance metrics

### Performance Benchmarks
```bash
# Expected results for 300 concurrent users:
Success Rate: >95%
Average Response Time: <2s
P95 Response Time: <3s
Peak Throughput: 400+ req/s
SSL Handshake Time: <100ms
Memory Usage: <4GB
CPU Usage: 60-80%
```

### CTF-Specific Analysis
```bash
# Check that security bypasses are still detected under load
./test-scripts/analyze-load-results.sh load-test-results/ctf_300users_TIMESTAMP

# Look for successful secret extractions
grep -i "secret\|bypass\|admin" load-test-results/ctf_300users_TIMESTAMP/ctf_successes.csv

# Verify WAF protection is working
grep -i "blocked\|waf" load-test-results/ctf_300users_TIMESTAMP/responses.log
```

## 🎯 Demo Readiness Checklist

### Pre-Demo Load Testing
- [ ] HTTPS load test passes with 300 users
- [ ] All security challenges work under load
- [ ] SSL certificates are valid and auto-renewing
- [ ] nginx-proxy performance is optimal
- [ ] Datadog monitoring captures all events
- [ ] Professional URLs work: https://dd-demo-sg-llm.com/*

### Load Test Results Validation
- [ ] Success rate >95%
- [ ] Response times <2s average
- [ ] No SSL errors in logs
- [ ] CTF bypasses detected correctly
- [ ] WAF protection working
- [ ] System resources stable under load

### Demo Day Preparation
- [ ] Run final load test morning of demo
- [ ] Verify all endpoints accessible
- [ ] Check SSL certificate expiry (should be >30 days)
- [ ] Confirm Datadog dashboards are ready
- [ ] Test security demonstrations work
- [ ] Have troubleshooting commands ready

## 🔧 Advanced Load Testing

### Custom Load Test Scenarios
```bash
# Test specific user journeys
./test-scripts/ctf-focused-load-test.sh 300 --scenario=prompt_injection

# Test sustained load (longer duration)
./test-scripts/multi-endpoint-load-test.sh 200 --duration=600

# Test spike traffic
./test-scripts/simple-load-test.sh 500 --duration=60
```

### Monitoring Integration
```bash
# Start Datadog monitoring before load test
# Monitor these dashboards during testing:
# - APM Performance
# - Infrastructure Metrics
# - LLM Observability
# - Custom Security Metrics
```

---

## 🎉 Success Metrics

Your HTTPS production setup is demo-ready when:
- ✅ **300+ concurrent users** handled successfully
- ✅ **Professional domain** with valid SSL certificates
- ✅ **Sub-2s response times** under full load
- ✅ **Security features** working correctly under load
- ✅ **Monitoring** capturing all performance data
- ✅ **Zero SSL errors** during load testing

**Your application is ready for professional demonstrations!** 🚀