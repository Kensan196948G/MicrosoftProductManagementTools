# Microsoft 365 Management Tools - Production Deployment Guide

## 🚀 Overview

This guide provides comprehensive instructions for deploying Microsoft 365 Management Tools to production environments using Docker, Kubernetes, and enterprise-grade CI/CD pipelines.

**Version:** 2.0  
**Target Audience:** DevOps Engineers, Site Reliability Engineers, Platform Engineers  
**Prerequisites:** Docker, Kubernetes, CI/CD pipeline experience

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-deployment Checklist](#pre-deployment-checklist)
3. [Environment Setup](#environment-setup)
4. [Configuration Management](#configuration-management)
5. [Security Hardening](#security-hardening)
6. [Deployment Methods](#deployment-methods)
7. [Monitoring & Observability](#monitoring--observability)
8. [Backup & Disaster Recovery](#backup--disaster-recovery)
9. [Troubleshooting](#troubleshooting)
10. [Maintenance & Updates](#maintenance--updates)

---

## 🔧 Prerequisites

### System Requirements

#### Minimum Requirements
- **CPU:** 2 cores
- **Memory:** 4 GB RAM
- **Storage:** 50 GB available space
- **Network:** HTTPS connectivity to Microsoft Graph API

#### Recommended Production Requirements
- **CPU:** 4+ cores
- **Memory:** 8+ GB RAM
- **Storage:** 100+ GB SSD storage
- **Network:** Dedicated outbound internet access, load balancer

### Software Requirements

#### Container Platform
- **Docker:** 20.10+ or compatible container runtime
- **Kubernetes:** 1.24+ (for Kubernetes deployments)
- **Docker Compose:** 2.0+ (for Docker Compose deployments)

#### CI/CD Tools
- **Git:** 2.30+
- **GitHub Actions** (or equivalent CI/CD platform)
- **kubectl:** Matching Kubernetes version
- **Helm:** 3.0+ (optional, for Helm deployments)

#### Security Tools
- **cert-manager:** 1.8+ (for automatic SSL certificate management)
- **Azure CLI:** 2.40+ (for Azure integrations)
- **AWS CLI:** 2.0+ (for AWS integrations)

#### Monitoring Stack
- **Prometheus:** 2.35+
- **Grafana:** 9.0+
- **AlertManager:** 0.24+

---

## ✅ Pre-deployment Checklist

### Infrastructure Readiness

- [ ] **Kubernetes cluster** provisioned and accessible
- [ ] **Container registry** configured (GitHub Container Registry, ACR, ECR)
- [ ] **DNS records** configured for application domains
- [ ] **Load balancer** or ingress controller deployed
- [ ] **SSL certificates** provisioned (Let's Encrypt, purchased certificates)
- [ ] **Persistent storage** configured for databases and file storage

### Security Configuration

- [ ] **Microsoft 365 app registration** created with required permissions
- [ ] **Service principal** created for Azure integrations
- [ ] **Network security groups** configured to restrict access
- [ ] **RBAC policies** defined and applied
- [ ] **Secrets management** solution configured (Azure Key Vault, AWS Secrets Manager)
- [ ] **Container image scanning** enabled in CI/CD pipeline

### Monitoring & Alerting

- [ ] **Prometheus** monitoring configured
- [ ] **Grafana** dashboards imported
- [ ] **AlertManager** routing rules configured
- [ ] **Notification channels** configured (email, Slack, Teams)
- [ ] **Log aggregation** solution deployed (Loki, ELK stack)

### Backup & Recovery

- [ ] **Backup storage** configured (Azure Storage, S3)
- [ ] **Backup schedule** defined and automated
- [ ] **Recovery procedures** documented and tested
- [ ] **Database backup** strategy implemented

---

## 🌍 Environment Setup

### Production Environment Variables

Create a `.env.production` file with the following configuration:

```bash
# Application Configuration
ENVIRONMENT=production
LOG_LEVEL=info
DEBUG=false

# Microsoft 365 Configuration
MICROSOFT_TENANT_ID=your-tenant-id
MICROSOFT_CLIENT_ID=your-client-id
MICROSOFT_CLIENT_SECRET=your-client-secret

# Database Configuration
DATABASE_URL=postgresql://user:password@postgres:5432/microsoft365_tools
DATABASE_POOL_SIZE=20
DATABASE_MAX_OVERFLOW=30

# Redis Configuration
REDIS_URL=redis://redis:6379/0
REDIS_POOL_SIZE=10

# Security Configuration
SECRET_KEY=your-super-secret-key-change-me
JWT_SECRET_KEY=your-jwt-secret-key
ENCRYPTION_KEY=your-encryption-key

# SSL/TLS Configuration
SSL_CERT_PATH=/app/certs/tls.crt
SSL_KEY_PATH=/app/certs/tls.key

# Monitoring Configuration
PROMETHEUS_METRICS_ENABLED=true
HEALTH_CHECK_INTERVAL=30

# Backup Configuration
BACKUP_ENABLED=true
BACKUP_SCHEDULE="0 2 * * *"  # Daily at 2 AM
AZURE_STORAGE_CONNECTION_STRING=your-connection-string
BACKUP_RETENTION_DAYS=30

# Notification Configuration
SMTP_HOST=smtp.company.com
SMTP_PORT=587
SMTP_USERNAME=alerts@company.com
SMTP_PASSWORD=your-smtp-password
TEAMS_WEBHOOK_URL=https://company.webhook.office.com/...
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
```

### Kubernetes Namespace Configuration

```bash
# Create production namespace
kubectl create namespace microsoft-365-tools

# Label namespace for monitoring
kubectl label namespace microsoft-365-tools \
  environment=production \
  monitoring=enabled \
  backup=enabled
```

---

## 🔐 Configuration Management

### Secrets Management

#### Azure Key Vault Integration

```bash
# Create Azure Key Vault
az keyvault create \
  --name "m365-tools-kv-prod" \
  --resource-group "m365-tools-rg" \
  --location "East US"

# Store secrets
az keyvault secret set --vault-name "m365-tools-kv-prod" \
  --name "microsoft-client-secret" \
  --value "your-secret"

az keyvault secret set --vault-name "m365-tools-kv-prod" \
  --name "database-password" \
  --value "your-db-password"
```

#### Kubernetes Secrets

```bash
# Create TLS secret
kubectl create secret tls m365-tools-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n microsoft-365-tools

# Create application secrets
kubectl create secret generic m365-secrets \
  --from-literal=MICROSOFT_CLIENT_SECRET="your-secret" \
  --from-literal=DATABASE_PASSWORD="your-password" \
  --from-literal=SECRET_KEY="your-secret-key" \
  -n microsoft-365-tools
```

### ConfigMaps

```bash
# Create application configuration
kubectl create configmap m365-config \
  --from-literal=LOG_LEVEL="info" \
  --from-literal=ENVIRONMENT="production" \
  --from-literal=HEALTH_CHECK_INTERVAL="30" \
  -n microsoft-365-tools
```

---

## 🛡️ Security Hardening

### Apply Security Policies

```bash
# Run security hardening script
./scripts/security/security-hardening.sh apply

# Verify security configuration
./scripts/security/security-hardening.sh validate

# Run security scan
./scripts/security/security-hardening.sh scan
```

### Certificate Management

```bash
# Generate production certificates
./scripts/security/certificate-manager.sh generate \
  --domain microsoft365tools.company.com \
  --email admin@company.com \
  --environment production

# Install certificates to Kubernetes
./scripts/security/certificate-manager.sh install \
  --namespace microsoft-365-tools

# Setup automatic renewal
./scripts/security/certificate-manager.sh schedule
```

---

## 🚀 Deployment Methods

### Method 1: GitHub Actions CI/CD (Recommended)

1. **Configure GitHub Secrets:**
   ```
   PRODUCTION_KUBE_CONFIG: Base64 encoded kubeconfig
   AZURE_CREDENTIALS: Azure service principal JSON
   MICROSOFT_CLIENT_SECRET: Microsoft Graph client secret
   PRODUCTION_DOCKER_PASSWORD: Container registry password
   ```

2. **Trigger Deployment:**
   ```bash
   # Create release tag
   git tag v2.0.0
   git push origin v2.0.0
   
   # Or trigger manual deployment
   gh workflow run production-deployment.yml \
     -f environment=production \
     -f skip_tests=false
   ```

3. **Monitor Deployment:**
   ```bash
   # Check workflow status
   gh run list --workflow=production-deployment.yml
   
   # View logs
   gh run view --log
   ```

### Method 2: Manual Kubernetes Deployment

1. **Build and Push Container Image:**
   ```bash
   # Build production image
   make docker-build VERSION=v2.0.0
   
   # Push to registry
   make docker-push VERSION=v2.0.0
   ```

2. **Deploy to Kubernetes:**
   ```bash
   # Deploy using deployment script
   ./scripts/kubernetes/deploy.sh \
     --tag v2.0.0 \
     --environment production \
     --namespace microsoft-365-tools
   
   # Or use Makefile
   make k8s-deploy-production VERSION=v2.0.0
   ```

3. **Verify Deployment:**
   ```bash
   # Check deployment status
   kubectl rollout status deployment/m365-tools-deployment \
     -n microsoft-365-tools
   
   # Check pods
   kubectl get pods -n microsoft-365-tools
   
   # Check services
   kubectl get services -n microsoft-365-tools
   ```

### Method 3: Docker Compose (Single Node)

1. **Prepare Environment:**
   ```bash
   # Copy production configuration
   cp .env.production .env
   
   # Update docker-compose.production.yml with correct values
   ```

2. **Deploy Services:**
   ```bash
   # Start all services
   docker-compose -f docker-compose.production.yml up -d
   
   # Or use Makefile
   make docker-compose-up
   ```

3. **Verify Services:**
   ```bash
   # Check service status
   docker-compose -f docker-compose.production.yml ps
   
   # View logs
   docker-compose -f docker-compose.production.yml logs -f
   ```

---

## 📊 Monitoring & Observability

### Prometheus Configuration

1. **Deploy Prometheus:**
   ```bash
   # Apply Prometheus configuration
   kubectl apply -f Config/monitoring/prometheus-rules.yml
   
   # Verify Prometheus is scraping targets
   kubectl port-forward svc/prometheus 9090:9090 -n monitoring
   # Open http://localhost:9090/targets
   ```

### Grafana Dashboards

1. **Import Dashboard:**
   ```bash
   # Import production dashboard
   kubectl create configmap grafana-dashboard \
     --from-file=Config/monitoring/grafana-dashboard.json \
     -n monitoring
   ```

2. **Access Grafana:**
   ```bash
   # Port forward to Grafana
   kubectl port-forward svc/grafana 3000:3000 -n monitoring
   # Open http://localhost:3000
   ```

### AlertManager Setup

1. **Configure Alerts:**
   ```bash
   # Apply AlertManager configuration
   kubectl apply -f Config/alertmanager.yml
   
   # Test alert routing
   curl -X POST http://alertmanager:9093/api/v1/alerts \
     -H "Content-Type: application/json" \
     -d '[{"labels":{"alertname":"TestAlert","severity":"warning"}}]'
   ```

---

## 💾 Backup & Disaster Recovery

### Automated Backup Setup

1. **Configure Backup:**
   ```bash
   # Setup automated backups
   ./scripts/backup/backup-system.sh schedule \
     --storage azure \
     --retention 30 \
     --encrypt \
     --compress
   ```

2. **Test Backup:**
   ```bash
   # Create test backup
   ./scripts/backup/backup-system.sh backup \
     --type full \
     --storage azure \
     --verify
   
   # List backups
   ./scripts/backup/backup-system.sh list --storage azure
   ```

### Disaster Recovery Procedures

1. **Prepare Recovery Environment:**
   ```bash
   # Setup new Kubernetes cluster
   # Configure same namespace and secrets
   kubectl create namespace microsoft-365-tools
   ```

2. **Restore from Backup:**
   ```bash
   # List available backups
   ./scripts/backup/backup-system.sh list --storage azure
   
   # Restore latest backup
   ./scripts/backup/backup-system.sh restore \
     --file m365-backup-production-full-20240120-120000.tar.gz \
     --storage azure
   ```

3. **Verify Recovery:**
   ```bash
   # Deploy application
   ./scripts/kubernetes/deploy.sh \
     --tag v2.0.0 \
     --environment production
   
   # Run health checks
   curl -f https://microsoft365tools.company.com/health
   ```

---

## 🔧 Troubleshooting

### Common Issues

#### Application Won't Start

**Symptoms:** Pods in CrashLoopBackOff state

**Diagnosis:**
```bash
# Check pod logs
kubectl logs -l app=m365-tools -n microsoft-365-tools --tail=100

# Check pod events
kubectl describe pod <pod-name> -n microsoft-365-tools

# Check configuration
kubectl get configmap m365-config -n microsoft-365-tools -o yaml
kubectl get secret m365-secrets -n microsoft-365-tools -o yaml
```

**Solutions:**
- Verify environment variables and secrets
- Check Microsoft Graph API credentials
- Ensure database connectivity
- Review resource limits and requests

#### Database Connection Issues

**Symptoms:** Database connection errors in logs

**Diagnosis:**
```bash
# Test database connectivity
kubectl exec -it deployment/m365-tools-deployment -n microsoft-365-tools -- \
  psql -h postgres -U m365user -d microsoft365_tools -c "SELECT 1;"

# Check database service
kubectl get svc postgres -n microsoft-365-tools
kubectl describe svc postgres -n microsoft-365-tools
```

**Solutions:**
- Verify database credentials
- Check network policies
- Ensure database service is running
- Review firewall rules

#### Certificate/SSL Issues

**Symptoms:** SSL certificate errors, HTTPS not working

**Diagnosis:**
```bash
# Check certificate status
./scripts/security/certificate-manager.sh check

# Check ingress configuration
kubectl describe ingress m365-tools-ingress -n microsoft-365-tools

# Test certificate validity
openssl s_client -connect microsoft365tools.company.com:443
```

**Solutions:**
- Renew expired certificates
- Update DNS records
- Check ingress controller configuration
- Verify certificate installation

#### Performance Issues

**Symptoms:** Slow response times, high resource usage

**Diagnosis:**
```bash
# Check resource usage
kubectl top pods -n microsoft-365-tools
kubectl top nodes

# Check application metrics
curl -s http://localhost:9090/metrics | grep -E "(cpu|memory|requests)"

# Review logs for errors
kubectl logs -l app=m365-tools -n microsoft-365-tools --since=1h
```

**Solutions:**
- Increase resource limits
- Scale horizontally (increase replicas)
- Optimize database queries
- Review Microsoft Graph API rate limits

### Debug Commands

```bash
# Get detailed pod information
kubectl get pods -n microsoft-365-tools -o wide

# Check all resources in namespace
kubectl get all -n microsoft-365-tools

# Check events for issues
kubectl get events -n microsoft-365-tools --sort-by='.lastTimestamp'

# Access application shell
kubectl exec -it deployment/m365-tools-deployment -n microsoft-365-tools -- /bin/bash

# Check application health endpoint
kubectl port-forward svc/m365-tools-service 8080:80 -n microsoft-365-tools
curl http://localhost:8080/health
```

---

## 🔄 Maintenance & Updates

### Regular Maintenance Tasks

#### Weekly Tasks
- [ ] Review monitoring dashboards and alerts
- [ ] Check backup integrity and success
- [ ] Review security scan results
- [ ] Monitor resource usage trends

#### Monthly Tasks
- [ ] Update dependencies and base images
- [ ] Review and rotate secrets
- [ ] Test disaster recovery procedures
- [ ] Cleanup old backups and logs
- [ ] Review and update documentation

#### Quarterly Tasks
- [ ] Review and update security policies
- [ ] Conduct security audit
- [ ] Performance optimization review
- [ ] Update monitoring and alerting rules

### Update Procedures

#### Application Updates

1. **Test in Staging:**
   ```bash
   # Deploy to staging
   ./scripts/kubernetes/deploy.sh \
     --tag v2.1.0 \
     --environment staging \
     --namespace microsoft-365-tools-staging
   ```

2. **Production Deployment:**
   ```bash
   # Create maintenance window
   # Scale down non-essential services
   
   # Deploy new version
   ./scripts/kubernetes/deploy.sh \
     --tag v2.1.0 \
     --environment production
   
   # Monitor deployment
   kubectl rollout status deployment/m365-tools-deployment \
     -n microsoft-365-tools
   ```

3. **Rollback if Needed:**
   ```bash
   # Rollback to previous version
   kubectl rollout undo deployment/m365-tools-deployment \
     -n microsoft-365-tools
   
   # Or use deployment script
   ./scripts/kubernetes/deploy.sh --rollback --environment production
   ```

#### Security Updates

1. **Certificate Renewal:**
   ```bash
   # Check certificate expiration
   ./scripts/security/certificate-manager.sh check
   
   # Renew certificates
   ./scripts/security/certificate-manager.sh renew --force
   ```

2. **Secret Rotation:**
   ```bash
   # Generate new secrets
   kubectl create secret generic m365-secrets-new \
     --from-literal=MICROSOFT_CLIENT_SECRET="new-secret" \
     -n microsoft-365-tools
   
   # Update deployment to use new secret
   kubectl patch deployment m365-tools-deployment \
     -p '{"spec":{"template":{"spec":{"containers":[{"name":"m365-tools","envFrom":[{"secretRef":{"name":"m365-secrets-new"}}]}]}}}}' \
     -n microsoft-365-tools
   
   # Delete old secret after verification
   kubectl delete secret m365-secrets -n microsoft-365-tools
   kubectl rename secret m365-secrets-new m365-secrets -n microsoft-365-tools
   ```

---

## 📞 Support & Escalation

### Support Contacts

- **DevOps Team:** devops-team@company.com
- **Security Team:** security@company.com  
- **Platform Team:** platform-team@company.com
- **On-call Engineer:** +1-555-0123 (24/7)

### Escalation Matrix

| Severity | Response Time | Escalation Path |
|----------|--------------|-----------------|
| Critical | 15 minutes | On-call → Team Lead → Manager |
| High | 1 hour | Team Member → Team Lead |
| Medium | 4 hours | Team Member → Team Lead |
| Low | 1 business day | Team Member |

### Emergency Procedures

1. **Immediate Response:**
   - Check monitoring dashboards
   - Review recent deployments
   - Check application logs
   - Verify infrastructure status

2. **Communication:**
   - Create incident ticket
   - Notify stakeholders via Teams/Slack
   - Update status page if applicable

3. **Resolution:**
   - Implement fix or rollback
   - Monitor for stability
   - Conduct post-incident review

---

## 📚 Additional Resources

### Documentation Links
- [Microsoft Graph API Documentation](https://docs.microsoft.com/en-us/graph/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [Prometheus Documentation](https://prometheus.io/docs/)

### Internal Resources
- [Company Kubernetes Runbook](internal-link)
- [Security Policies](internal-link)
- [Monitoring Standards](internal-link)
- [Incident Response Procedures](internal-link)

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-21  
**Next Review:** 2025-04-21  
**Maintained By:** DevOps Team