#!/bin/bash
# Script to start all required port-forwards for the load balancer test dashboard

echo "🚀 Starting port-forwards for Load Balancer Test Dashboard..."
echo ""

# Kill existing port-forwards if any
pkill -f "kubectl port-forward.*31080" 2>/dev/null
pkill -f "kubectl port-forward.*31081" 2>/dev/null
pkill -f "kubectl port-forward.*8080.*ingress-nginx" 2>/dev/null

# Start port-forwards in background
echo "📡 Setting up port-forwards..."
kubectl port-forward -n cluster-hot svc/backend-service-nodeport 31080:80 > /dev/null 2>&1 &
echo "  ✓ Hot cluster (port 31080)"

kubectl port-forward -n cluster-standby svc/backend-service-nodeport 31081:80 > /dev/null 2>&1 &
echo "  ✓ Standby cluster (port 31081)"

kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 > /dev/null 2>&1 &
echo "  ✓ Ingress controller (port 8080)"

# Wait a moment for port-forwards to establish
sleep 2

# Test connectivity
echo ""
echo "🧪 Testing connectivity..."
if curl -s http://localhost:31080/healthz > /dev/null 2>&1; then
    echo "  ✅ Hot cluster is accessible"
else
    echo "  ❌ Hot cluster connection failed"
fi

if curl -s http://localhost:31081/healthz > /dev/null 2>&1; then
    echo "  ✅ Standby cluster is accessible"
else
    echo "  ❌ Standby cluster connection failed"
fi

if curl -s -H "Host: backend.local" http://localhost:8080/healthz > /dev/null 2>&1; then
    echo "  ✅ Load balancer is accessible"
else
    echo "  ⚠️  Load balancer may need /etc/hosts entry: 192.168.49.2 backend.local"
fi

echo ""
echo "✅ Port-forwards are running!"
echo ""
echo "📊 Dashboard URL: http://localhost:8000/loadbalancer-test.html"
echo ""
echo "To stop port-forwards, run:"
echo "  pkill -f 'kubectl port-forward'"

