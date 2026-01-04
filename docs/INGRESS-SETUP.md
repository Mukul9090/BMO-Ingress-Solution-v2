# NGINX Ingress Setup for Two-Cluster Architecture

This guide explains how to set up and configure NGINX Ingress Controller for active-passive routing between two separate Kubernetes clusters.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│         NGINX Ingress Controller                        │
│    (Single external controller routing to both)         │
│         Port: 80/443 (or custom)                        │
└──────────────┬──────────────────────┬───────────────────┘
               │                      │
               │ Ingress Rules        │
               │                      │
    ┌──────────▼──────────┐  ┌────────▼──────────┐
    │  Cluster 1 (Hot)   │  │ Cluster 2 (Standby)│
    │  - backend-service  │  │  - backend-service │
    │  - CLUSTER_ROLE=hot │  │  - CLUSTER_ROLE=   │
    │                     │  │    standby         │
    │  Service: ClusterIP │  │  Service: ClusterIP│
    └─────────────────────┘  └────────────────────┘
```

## Prerequisites

- Two Kubernetes clusters (or Minikube instances)
- kubectl configured to access both clusters
- Docker image `backend-service:latest` available
- NGINX Ingress Controller (will be installed)

## Installation Methods

### Method 1: Minikube Addon (Recommended for Local Development)

```bash
minikube addons enable ingress
```

This is the simplest method for local development with Minikube.

### Method 2: Helm Installation

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace
```

### Method 3: Official Manifests

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

## Deployment Steps

### Step 1: Deploy Hot Cluster

```bash
./deploy-cluster-hot.sh
```

Or with custom context:
```bash
CLUSTER_CONTEXT=minikube-hot ./deploy-cluster-hot.sh
```

### Step 2: Deploy Standby Cluster

```bash
./deploy-cluster-standby.sh
```

Or with custom context:
```bash
CLUSTER_CONTEXT=minikube-standby ./deploy-cluster-standby.sh
```

### Step 3: Install NGINX Ingress

```bash
./deploy-ingress.sh
```

Or with custom method:
```bash
INGRESS_METHOD=helm ./deploy-ingress.sh
```

### Step 4: Deploy All (Automated)

```bash
./deploy-all.sh
```

## Configuration Files

### Ingress Resources

- `k8s/ingress/backend-ingress.yaml` - Primary Ingress resource
- `k8s/ingress/backend-ingress-active-passive.yaml` - Active-passive configuration
- `k8s/ingress/external-services.yaml` - Service endpoints for cross-cluster routing
- `k8s/ingress/nginx-configmap.yaml` - NGINX Ingress Controller configuration

### Service Discovery

For cross-cluster service discovery, we use ExternalName services that point to the cluster services:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-hot-service
spec:
  type: ExternalName
  externalName: backend-service.cluster-hot.svc.cluster.local
```

**Note:** For truly separate clusters, you may need to:
1. Use NodePort services and reference them via IP:Port
2. Use ExternalName services pointing to cluster IPs
3. Configure network policies to allow cross-cluster communication

## Active-Passive Configuration with Automatic Failover

The setup uses a combined service (`backend-service-combined`) that includes endpoints from both hot and standby clusters. NGINX Ingress automatically performs health checks and retries failed requests, providing automatic failover capability.

### How Failover Works

1. **Combined Service:** A single service includes endpoints from both clusters
2. **Health Checks:** NGINX Ingress monitors pod health via readiness probes
3. **Automatic Retry:** On failure/timeout, requests automatically retry to standby
4. **Load Balancing:** Traffic is distributed across healthy pods in both clusters

### Failover Behavior

1. **Normal Operation:** Traffic routes to both clusters (load balanced)
2. **Hot Cluster Failure:** Failed requests automatically retry to standby cluster
3. **Hot Cluster Recovery:** Traffic resumes to both clusters once healthy

### Configuration Details

The failover is configured via:
- **Combined Service:** `backend-service-combined` with endpoints from both clusters
- **Ingress Annotations:** Retry and timeout settings for automatic failover
- **Health Checks:** Readiness probes ensure only healthy pods receive traffic

### Testing Failover

**Automated Test Script:**
```bash
./scripts/test-failover.sh
```

**Manual Testing:**
```bash
# 1. Update endpoints to include current pod IPs
./scripts/update-endpoints.sh

# 2. Scale down hot cluster to simulate failure
kubectl scale deployment backend-service -n cluster-hot --replicas=0

# 3. Wait a moment, then update endpoints
./scripts/update-endpoints.sh

# 4. Test via Ingress (requires port-forward)
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 9090:80
curl -H "Host: backend.local" http://localhost:9090/healthz

# 5. Restore hot cluster
kubectl scale deployment backend-service -n cluster-hot --replicas=3
./scripts/update-endpoints.sh
```

**Note:** The endpoints need to be updated when pods are created/destroyed. The `update-endpoints.sh` script handles this automatically.

## Accessing the Service

### Local Development (Minikube)

1. **Get Minikube IP:**
   ```bash
   minikube ip
   ```

2. **Add to /etc/hosts:**
   ```
   <minikube-ip> backend.local
   ```

3. **Access the service:**
   ```bash
   curl http://backend.local/healthz
   curl http://backend.local/
   ```

### Port Forwarding (Alternative)

```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
curl http://localhost:8080/healthz
```

## Troubleshooting

### Ingress Controller Not Ready

```bash
# Check Ingress controller status
kubectl get pods -n ingress-nginx

# View Ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f
```

### Services Not Accessible

```bash
# Verify services exist
kubectl get svc -n cluster-hot
kubectl get svc -n cluster-standby
kubectl get svc -n default | grep backend

# Check Ingress resource
kubectl describe ingress backend-ingress
```

### Cross-Cluster Connectivity Issues

For separate clusters, ensure:
1. Network connectivity between clusters
2. NodePort services are created if needed
3. ExternalName services point to correct endpoints
4. Firewall rules allow traffic

### Health Checks Failing

```bash
# Check pod health
kubectl get pods -n cluster-hot
kubectl get pods -n cluster-standby

# Check readiness probes
kubectl describe pod -n cluster-hot <pod-name>

# Test health endpoint directly
kubectl exec -it -n cluster-hot <pod-name> -- curl localhost:8080/healthz
```

## Advanced Configuration

### Custom NGINX Configuration

Edit `k8s/ingress/nginx-configmap.yaml` to customize:
- Upstream keepalive settings
- Timeout values
- Logging format
- Custom headers

### SSL/TLS Configuration

To enable HTTPS:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
    - hosts:
        - backend.local
      secretName: backend-tls
  rules:
    - host: backend.local
      ...
```

### Rate Limiting

Add rate limiting annotations:

```yaml
annotations:
  nginx.ingress.kubernetes.io/limit-rps: "100"
  nginx.ingress.kubernetes.io/limit-connections: "10"
```

## Monitoring

### View Ingress Metrics

```bash
# Port forward to metrics endpoint
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 10254:10254

# Access metrics
curl http://localhost:10254/metrics
```

### Check Request Headers

NGINX Ingress adds custom headers:
- `X-Cluster-Role`: Identifies which cluster is serving the request
- `X-Cluster-Status`: Indicates primary or backup status

## Cleanup

To remove all resources:

```bash
# Delete Ingress resources
kubectl delete -f k8s/ingress/

# Delete clusters
kubectl delete -f k8s/cluster-hot/
kubectl delete -f k8s/cluster-standby/

# Remove Ingress controller (if installed via addon)
minikube addons disable ingress

# Or if installed via Helm
helm uninstall ingress-nginx -n ingress-nginx
```

## References

- [NGINX Ingress Controller Documentation](https://kubernetes.github.io/ingress-nginx/)
- [Kubernetes Ingress Documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [NGINX Ingress Annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/)

