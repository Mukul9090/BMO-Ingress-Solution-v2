#!/bin/bash
# Deployment Script for Standby Cluster
# This script deploys the backend service to the standby cluster

set -e

CLUSTER_NAME="${CLUSTER_NAME:-minikube-standby}"
CLUSTER_CONTEXT="${CLUSTER_CONTEXT:-}"
IMAGE_TAG="${IMAGE_TAG:-}"
CI_CD_MODE="${CI_CD_MODE:-false}"

echo "=== Deploying Standby Cluster ==="
echo "Cluster: $CLUSTER_NAME"
[ -n "$IMAGE_TAG" ] && echo "Image Tag: $IMAGE_TAG"
[ "$CI_CD_MODE" = "true" ] && echo "Mode: CI/CD (skipping local-only steps)"

# Set kubectl context if provided
if [ -n "$CLUSTER_CONTEXT" ]; then
    echo "Switching to context: $CLUSTER_CONTEXT"
    kubectl config use-context "$CLUSTER_CONTEXT"
fi

echo ""
echo "=== Step 1: Loading Docker Image ==="
# Skip minikube image load in CI/CD mode
if [ "$CI_CD_MODE" = "true" ]; then
    echo "⏭️  CI/CD mode: Skipping Minikube image load (using registry image)"
elif command -v minikube &> /dev/null && minikube status &> /dev/null; then
    echo "Loading image into Minikube..."
    minikube image load backend-service:latest || echo "⚠ Image load failed, ensure image exists"
else
    echo "⚠ Minikube not detected, skipping image load"
    echo "   Ensure image is available in your cluster or registry"
fi

echo ""
echo "=== Step 2: Updating Deployment Image ==="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Update deployment image if IMAGE_TAG is provided
if [ -n "$IMAGE_TAG" ]; then
    echo "Updating deployment image to: $IMAGE_TAG"
    if [ -f "k8s/cluster-standby/deployment.yaml" ]; then
        # Use sed to update image (works on both Linux and macOS)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|image:.*|image: $IMAGE_TAG|g" k8s/cluster-standby/deployment.yaml
        else
            sed -i "s|image:.*|image: $IMAGE_TAG|g" k8s/cluster-standby/deployment.yaml
        fi
        echo "✓ Deployment image updated"
    else
        echo "⚠ Warning: deployment.yaml not found"
    fi
fi

echo ""
echo "=== Step 3: Applying Kubernetes Manifests ==="

# In CI/CD mode, disable validation if cluster is not directly accessible
VALIDATE_FLAG=""
if [ "$CI_CD_MODE" = "true" ]; then
    # Test if we can reach the cluster for validation
    if ! kubectl cluster-info --request-timeout=5s &>/dev/null; then
        VALIDATE_FLAG="--validate=false"
        echo "ℹ️  Cluster not directly accessible, disabling manifest validation"
    fi
fi

echo "Creating namespace..."
kubectl apply $VALIDATE_FLAG -f k8s/cluster-standby/namespace.yaml
echo "✓ Namespace created"

echo "Creating ConfigMap..."
kubectl apply $VALIDATE_FLAG -f k8s/cluster-standby/configmap.yaml
echo "✓ ConfigMap created"

echo "Creating Deployment..."
kubectl apply $VALIDATE_FLAG -f k8s/cluster-standby/deployment.yaml
echo "✓ Deployment created"

echo "Creating Service (ClusterIP)..."
kubectl apply $VALIDATE_FLAG -f k8s/cluster-standby/service.yaml
echo "✓ Service created"

# Optionally create NodePort service for cross-cluster access
if [ "${CREATE_NODEPORT:-false}" = "true" ]; then
    echo "Creating NodePort Service..."
    kubectl apply $VALIDATE_FLAG -f k8s/cluster-standby/service-nodeport.yaml
    echo "✓ NodePort Service created"
fi

echo ""
echo "=== Step 4: Waiting for Deployment Rollout ==="
kubectl rollout status deployment/backend-service -n cluster-standby --timeout=300s || {
    echo "❌ Deployment rollout failed or timed out"
    echo "Checking deployment status..."
    kubectl describe deployment backend-service -n cluster-standby
    kubectl get pods -n cluster-standby -l app=backend-service,cluster=standby
    exit 1
}

echo ""
echo "=== Step 5: Waiting for Pods to be Ready ==="
kubectl wait --for=condition=ready pod -l app=backend-service,cluster=standby -n cluster-standby --timeout=120s || {
    echo "⚠ Warning: Some pods may not be ready yet"
    echo "Checking pod status..."
    kubectl get pods -n cluster-standby -l app=backend-service,cluster=standby
    kubectl describe pods -n cluster-standby -l app=backend-service,cluster=standby | tail -20
    exit 1
}

echo ""
echo "=== Step 6: Deployment Status ==="
echo "📊 Pods:"
kubectl get pods -n cluster-standby -l app=backend-service,cluster=standby -o wide
echo ""
echo "📊 Services:"
kubectl get svc -n cluster-standby
echo ""
echo "📊 Deployment:"
kubectl get deployment -n cluster-standby

echo ""
echo "=== ✅ Standby Cluster Deployment Complete! ==="
echo ""
echo "📋 Useful Commands:"
echo "  View logs: kubectl logs -n cluster-standby -l app=backend-service,cluster=standby -f"
echo "  Check service: kubectl get svc -n cluster-standby"
echo "  Describe deployment: kubectl describe deployment backend-service -n cluster-standby"

