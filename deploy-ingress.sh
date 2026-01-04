#!/bin/bash
# Deployment Script for NGINX Ingress Controller
# This script installs and configures NGINX Ingress Controller

set -e

INGRESS_METHOD="${INGRESS_METHOD:-minikube}"
CI_CD_MODE="${CI_CD_MODE:-false}"

# In CI/CD, default to manifest method
if [ "$CI_CD_MODE" = "true" ] && [ "$INGRESS_METHOD" = "minikube" ]; then
    INGRESS_METHOD="manifest"
    echo "ℹ️  CI/CD mode: Using manifest method instead of minikube"
fi

echo "=== Installing NGINX Ingress Controller ==="
echo "Method: $INGRESS_METHOD"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

case "$INGRESS_METHOD" in
    minikube)
        echo ""
        echo "=== Step 1: Enabling Minikube Ingress Addon ==="
        if command -v minikube &> /dev/null; then
            minikube addons enable ingress
            echo "✓ Ingress addon enabled"
            
            echo ""
            echo "Waiting for Ingress controller to be ready..."
            kubectl wait --namespace ingress-nginx \
                --for=condition=ready pod \
                --selector=app.kubernetes.io/component=controller \
                --timeout=120s || {
                echo "⚠ Ingress controller may still be starting"
            }
        else
            echo "❌ Minikube not found. Please install Minikube or use another method."
            exit 1
        fi
        ;;
    
    helm)
        echo ""
        echo "=== Step 1: Installing via Helm ==="
        if ! command -v helm &> /dev/null; then
            echo "❌ Helm not found. Please install Helm first."
            exit 1
        fi
        
        echo "Adding NGINX Ingress Helm repository..."
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
        helm repo update
        
        echo "Installing NGINX Ingress Controller..."
        helm install ingress-nginx ingress-nginx/ingress-nginx \
            --namespace ingress-nginx \
            --create-namespace \
            --set controller.service.type=NodePort
        
        echo "✓ Ingress installed via Helm"
        
        echo ""
        echo "Waiting for Ingress controller to be ready..."
        kubectl wait --namespace ingress-nginx \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/component=controller \
            --timeout=120s || {
            echo "⚠ Ingress controller may still be starting"
        }
        ;;
    
    manifest)
        echo ""
        echo "=== Step 1: Installing via Official Manifests ==="
        echo "Downloading and applying NGINX Ingress Controller manifests..."
        
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
        
        echo "✓ Ingress installed via manifests"
        
        echo ""
        echo "Waiting for Ingress controller to be ready..."
        kubectl wait --namespace ingress-nginx \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/component=controller \
            --timeout=120s || {
            echo "⚠ Ingress controller may still be starting"
        }
        ;;
    
    *)
        echo "❌ Unknown ingress method: $INGRESS_METHOD"
        echo "Supported methods: minikube, helm, manifest"
        exit 1
        ;;
esac

echo ""
echo "=== Step 2: Applying NGINX Configuration ==="
if [ -f "k8s/ingress/nginx-configmap.yaml" ]; then
    kubectl apply -f k8s/ingress/nginx-configmap.yaml
    echo "✓ NGINX ConfigMap applied"
else
    echo "⚠ NGINX ConfigMap not found, skipping"
fi

echo ""
echo "=== Step 3: Creating External Services ==="
if [ -f "k8s/ingress/external-services.yaml" ]; then
    kubectl apply -f k8s/ingress/external-services.yaml
    echo "✓ External services created"
else
    echo "⚠ External services manifest not found, skipping"
fi

echo ""
echo "=== Step 4: Applying Ingress Resources ==="
# Apply combined service and endpoints first
if [ -f "k8s/ingress/backend-service-combined.yaml" ]; then
    kubectl apply -f k8s/ingress/backend-service-combined.yaml
    echo "✓ Combined service and endpoints applied"
fi

# Apply the simple ingress (primary)
if [ -f "k8s/ingress/backend-ingress-simple.yaml" ]; then
    kubectl apply -f k8s/ingress/backend-ingress-simple.yaml
    echo "✓ Primary Ingress resource applied"
elif [ -f "k8s/ingress/backend-ingress.yaml" ]; then
    kubectl apply -f k8s/ingress/backend-ingress.yaml
    echo "✓ Primary Ingress resource applied"
fi

# Apply active-passive ingress (optional)
if [ -f "k8s/ingress/backend-ingress-active-passive.yaml" ]; then
    kubectl apply -f k8s/ingress/backend-ingress-active-passive.yaml
    echo "✓ Active-Passive Ingress resources applied"
fi

echo ""
echo "=== Step 5: Verifying Ingress Installation ==="
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get ingress

echo ""
echo "=== NGINX Ingress Installation Complete! ==="
echo ""
echo "To access the service:"
echo "1. Add to /etc/hosts: $(minikube ip 2>/dev/null || echo '<ingress-ip>') backend.local"
echo "2. Or use port-forward: kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80"
echo ""
echo "To view Ingress controller logs:"
echo "kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f"

