#!/bin/bash
# Post-deployment health check tests

set -e

echo "=== Post-Deployment Health Checks ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
TIMEOUT=300  # 5 minutes timeout
INTERVAL=10  # Check every 10 seconds

# Function to check if pods are ready
check_pods_ready() {
    local namespace=$1
    local selector=$2
    local expected_replicas=${3:-1}
    
    echo "Checking pods in namespace: $namespace with selector: $selector"
    
    local ready_count=0
    local elapsed=0
    
    while [ $elapsed -lt $TIMEOUT ]; do
        ready_count=$(kubectl get pods -n "$namespace" -l "$selector" \
            --field-selector=status.phase=Running \
            -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' \
            2>/dev/null | grep -o "True" | wc -l || echo "0")
        
        if [ "$ready_count" -ge "$expected_replicas" ]; then
            echo -e "${GREEN}✓ All $expected_replicas pod(s) are ready in $namespace${NC}"
            return 0
        fi
        
        echo "Waiting for pods... ($ready_count/$expected_replicas ready, ${elapsed}s elapsed)"
        sleep $INTERVAL
        elapsed=$((elapsed + INTERVAL))
    done
    
    echo -e "${RED}❌ Timeout waiting for pods in $namespace${NC}"
    kubectl get pods -n "$namespace" -l "$selector"
    return 1
}

# Function to check service endpoints
check_service_endpoints() {
    local namespace=$1
    local service_name=$2
    
    echo "Checking service endpoints for $service_name in $namespace"
    
    local endpoints=$(kubectl get endpoints -n "$namespace" "$service_name" \
        -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
    
    if [ -z "$endpoints" ]; then
        echo -e "${RED}❌ No endpoints found for service $service_name${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Service $service_name has endpoints: $endpoints${NC}"
    return 0
}

# Function to test HTTP endpoint (if accessible)
test_http_endpoint() {
    local url=$1
    local expected_role=${2:-""}
    
    echo "Testing HTTP endpoint: $url"
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ]; then
        if [ -n "$expected_role" ]; then
            local role=$(curl -s --max-time 5 "$url" 2>/dev/null | grep -o "\"role\":\"[^\"]*\"" | cut -d'"' -f4 || echo "")
            if [ "$role" = "$expected_role" ]; then
                echo -e "${GREEN}✓ Endpoint $url is healthy with role: $role${NC}"
                return 0
            else
                echo -e "${YELLOW}⚠️  Endpoint $url returned role: $role (expected: $expected_role)${NC}"
            fi
        else
            echo -e "${GREEN}✓ Endpoint $url is healthy${NC}"
            return 0
        fi
    else
        echo -e "${YELLOW}⚠️  Endpoint $url returned status: $response${NC}"
    fi
    
    return 1
}

# Main test execution
echo ""
echo "=== Testing Hot Cluster Deployment ==="
if kubectl get namespace cluster-hot &>/dev/null; then
    check_pods_ready "cluster-hot" "app=backend-service,cluster=hot" 3 || ((ERRORS++))
    check_service_endpoints "cluster-hot" "backend-service" || ((ERRORS++))
else
    echo -e "${YELLOW}⚠️  Namespace cluster-hot not found${NC}"
fi

echo ""
echo "=== Testing Standby Cluster Deployment ==="
if kubectl get namespace cluster-standby &>/dev/null; then
    check_pods_ready "cluster-standby" "app=backend-service,cluster=standby" 3 || ((ERRORS++))
    check_service_endpoints "cluster-standby" "backend-service" || ((ERRORS++))
else
    echo -e "${YELLOW}⚠️  Namespace cluster-standby not found${NC}"
fi

echo ""
echo "=== Testing Ingress Controller ==="
if kubectl get namespace ingress-nginx &>/dev/null; then
    check_pods_ready "ingress-nginx" "app.kubernetes.io/component=controller" 1 || ((ERRORS++))
else
    echo -e "${YELLOW}⚠️  Namespace ingress-nginx not found${NC}"
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All post-deployment checks passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS error(s) in post-deployment checks${NC}"
    exit 1
fi

