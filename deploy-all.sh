#!/bin/bash
# Master Deployment Script
# This script deploys both clusters and configures NGINX Ingress

set -e

# Configuration
HOT_CLUSTER_CONTEXT="${HOT_CLUSTER_CONTEXT:-}"
STANDBY_CLUSTER_CONTEXT="${STANDBY_CLUSTER_CONTEXT:-}"
INGRESS_METHOD="${INGRESS_METHOD:-minikube}"
CREATE_NODEPORT="${CREATE_NODEPORT:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  Two-Cluster Deployment with Ingress"
echo "=========================================="
echo ""

# Check prerequisites
echo "=== Checking Prerequisites ==="
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl."
    exit 1
fi
echo "✓ kubectl found"

if [ "$INGRESS_METHOD" = "minikube" ] && ! command -v minikube &> /dev/null; then
    echo "⚠ Minikube not found. Ingress installation may fail."
fi

echo ""
echo "=== Configuration ==="
echo "Hot Cluster Context: ${HOT_CLUSTER_CONTEXT:-default}"
echo "Standby Cluster Context: ${STANDBY_CLUSTER_CONTEXT:-default}"
echo "Ingress Method: $INGRESS_METHOD"
echo "Create NodePort Services: $CREATE_NODEPORT"
echo ""

# Deploy Hot Cluster
echo "=========================================="
echo "  Step 1: Deploying Hot Cluster"
echo "=========================================="
export CLUSTER_CONTEXT="$HOT_CLUSTER_CONTEXT"
export CREATE_NODEPORT
bash "$SCRIPT_DIR/deploy-cluster-hot.sh"

echo ""
echo "Press Enter to continue to standby cluster deployment..."
read -r

# Deploy Standby Cluster
echo "=========================================="
echo "  Step 2: Deploying Standby Cluster"
echo "=========================================="
export CLUSTER_CONTEXT="$STANDBY_CLUSTER_CONTEXT"
export CREATE_NODEPORT
bash "$SCRIPT_DIR/deploy-cluster-standby.sh"

echo ""
echo "Press Enter to continue to Ingress installation..."
read -r

# Deploy Ingress
echo "=========================================="
echo "  Step 3: Installing NGINX Ingress"
echo "=========================================="
export INGRESS_METHOD
bash "$SCRIPT_DIR/deploy-ingress.sh"

echo ""
echo "=========================================="
echo "  Deployment Complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ Hot cluster deployed"
echo "  ✓ Standby cluster deployed"
echo "  ✓ NGINX Ingress Controller installed"
echo ""
echo "Next Steps:"
echo "1. Verify deployments:"
echo "   kubectl get pods -n cluster-hot"
echo "   kubectl get pods -n cluster-standby"
echo "   kubectl get ingress"
echo ""
echo "2. Access the service:"
if command -v minikube &> /dev/null; then
    MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "<minikube-ip>")
    echo "   Add to /etc/hosts: $MINIKUBE_IP backend.local"
    echo "   Then access: http://backend.local/"
else
    echo "   Configure DNS or use port-forward to access the service"
fi
echo ""
echo "3. Test failover:"
echo "   Scale down hot cluster: kubectl scale deployment backend-service -n cluster-hot --replicas=0"
echo "   Verify traffic routes to standby cluster"
echo ""
echo "4. View logs:"
echo "   Hot cluster: kubectl logs -n cluster-hot -l app=backend-service,cluster=hot -f"
echo "   Standby cluster: kubectl logs -n cluster-standby -l app=backend-service,cluster=standby -f"
echo "   Ingress: kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f"

