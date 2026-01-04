# Backend Service - High Availability Demo

A minimal Flask REST API for demonstrating hot/standby failover behavior with two separate Kubernetes clusters and NGINX Ingress Controller.

## Architecture

This project implements an active-passive high availability setup using:
- **Two separate Kubernetes clusters** (hot and standby)
- **NGINX Ingress Controller** for load balancing and automatic failover
- **Active-Passive routing** with automatic health check-based failover

```
┌─────────────────────────────────────────────────────────┐
│         NGINX Ingress Controller                        │
│    (Single external controller routing to both)        │
└──────────────┬──────────────────────┬───────────────────┘
               │                      │
    ┌──────────▼──────────┐  ┌────────▼──────────┐
    │  Cluster 1 (Hot)   │  │ Cluster 2 (Standby)│
    │  - backend-service  │  │  - backend-service │
    │  - CLUSTER_ROLE=hot │  │  - CLUSTER_ROLE=   │
    │                     │  │    standby         │
    └─────────────────────┘  └────────────────────┘
```

## Project Structure

```
.
├── server.py                    # Main Flask application
├── requirements.txt             # Python dependencies
├── Dockerfile                   # Container image definition
├── deploy-cluster-hot.sh        # Deploy hot cluster
├── deploy-cluster-standby.sh    # Deploy standby cluster
├── deploy-ingress.sh            # Install NGINX Ingress
├── deploy-all.sh                # Master deployment script
├── k8s/                         # Kubernetes manifests
│   ├── cluster-hot/             # Hot cluster manifests
│   │   ├── namespace.yaml
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── service-nodeport.yaml
│   ├── cluster-standby/         # Standby cluster manifests
│   │   ├── namespace.yaml
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── service-nodeport.yaml
│   └── ingress/                 # Ingress configuration
│       ├── backend-ingress.yaml
│       ├── backend-ingress-active-passive.yaml
│       ├── external-services.yaml
│       └── nginx-configmap.yaml
└── docs/                        # Documentation
    ├── DEPLOY.md                # Kubernetes deployment guide
    ├── MINIKUBE.md              # Minikube-specific guide
    └── INGRESS-SETUP.md         # NGINX Ingress setup guide
```

## Running Locally with Python

### Prerequisites
- Python 3.11 or higher
- pip

### Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Run the application:

**Hot (Primary) Instance:**
```bash
CLUSTER_ROLE=hot python server.py
```

**Standby Instance:**
```bash
CLUSTER_ROLE=standby python server.py
```

**Default (Unknown Role):**
```bash
python server.py
```

The application will be available at `http://localhost:8080`

### Testing Endpoints

**Health Check:**
```bash
curl http://localhost:8080/healthz
```

**Root Endpoint:**
```bash
curl http://localhost:8080/
```

## Running with Docker

### Build the image:
```bash
docker build -t backend-service .
```

### Run containers:

**Hot (Primary) Instance:**
```bash
docker run -p 8080:8080 -e CLUSTER_ROLE=hot backend-service
```

**Standby Instance:**
```bash
docker run -p 8081:8080 -e CLUSTER_ROLE=standby backend-service
```

Note: The standby instance uses port 8081 to avoid port conflicts when running both instances on the same machine.

### Testing Docker Containers

**Hot Instance:**
```bash
curl http://localhost:8080/healthz
curl http://localhost:8080/
```

**Standby Instance:**
```bash
curl http://localhost:8081/healthz
curl http://localhost:8081/
```

## CI/CD with GitHub Actions

This project includes GitHub Actions workflows for automated testing, building, and deployment.

### Quick Start

1. **Configure Secrets** (required for deployment):
   - `KUBECONFIG_HOT` - Base64-encoded kubeconfig for hot cluster
   - `KUBECONFIG_STANDBY` - Base64-encoded kubeconfig for standby cluster

2. **Push to main branch** - Automatically triggers full CI/CD pipeline

3. **Manual deployment** - Go to Actions tab → CI/CD → Run workflow

For detailed CI/CD documentation, see [docs/CI-CD.md](docs/CI-CD.md).

## Kubernetes Deployment (Two-Cluster Setup)

### Prerequisites

- Two Kubernetes clusters (or Minikube instances)
- kubectl configured
- Docker image `backend-service:latest` built
- NGINX Ingress Controller (will be installed automatically)

### Quick Start (Automated)

Deploy both clusters and Ingress with a single command:

```bash
# Build Docker image first
docker build -t backend-service:latest .

# Deploy everything
./deploy-all.sh
```

### Manual Deployment

**Step 1: Deploy Hot Cluster**
```bash
./deploy-cluster-hot.sh
```

**Step 2: Deploy Standby Cluster**
```bash
./deploy-cluster-standby.sh
```

**Step 3: Install NGINX Ingress**
```bash
./deploy-ingress.sh
```

### Accessing the Service

**For Minikube:**
```bash
# Get Minikube IP
minikube ip

# Add to /etc/hosts
echo "$(minikube ip) backend.local" | sudo tee -a /etc/hosts

# Access the service
curl http://backend.local/healthz
curl http://backend.local/
```

**Alternative (Port Forwarding):**
```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
curl http://localhost:8080/healthz
```

### Documentation

- [NGINX Ingress Setup Guide](docs/INGRESS-SETUP.md) - Detailed Ingress configuration
- [Minikube Deployment Guide](docs/MINIKUBE.md) - Minikube-specific instructions
- [General Deployment Guide](docs/DEPLOY.md) - General Kubernetes deployment

## Testing Failover

### Automatic Failover Testing

NGINX Ingress Controller automatically performs health checks and routes traffic away from unhealthy backends.

**Simulate Hot Cluster Failure:**
```bash
# Scale down hot cluster
kubectl scale deployment backend-service -n cluster-hot --replicas=0

# Verify traffic routes to standby
curl http://backend.local/healthz
# Should show: "role": "standby"
```

**Restore Hot Cluster:**
```bash
# Scale up hot cluster
kubectl scale deployment backend-service -n cluster-hot --replicas=3

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=backend-service,cluster=hot -n cluster-hot --timeout=120s

# Verify traffic routes back to hot
curl http://backend.local/healthz
# Should show: "role": "hot"
```

### Monitoring

**View Cluster Status:**
```bash
# Hot cluster
kubectl get pods -n cluster-hot
kubectl logs -n cluster-hot -l app=backend-service,cluster=hot -f

# Standby cluster
kubectl get pods -n cluster-standby
kubectl logs -n cluster-standby -l app=backend-service,cluster=standby -f

# Ingress controller
kubectl get ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f
```

### Local Development (Docker)

To test failover behavior locally with Docker:

1. Start the hot instance on port 8080
2. Start the standby instance on port 8081
3. Monitor both instances using their `/healthz` endpoints
4. Simulate a failure by stopping the hot instance
5. The standby instance can then be promoted to hot (by restarting with `CLUSTER_ROLE=hot`)
