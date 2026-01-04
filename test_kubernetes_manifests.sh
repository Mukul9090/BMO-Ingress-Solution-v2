#!/bin/bash
# Test script to validate Kubernetes manifests

set -e

echo "=== Testing Kubernetes Manifests ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Function to validate YAML files
validate_yaml() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}⚠️  File not found: $file${NC}"
        return 1
    fi
    
    # Check if file is valid YAML
    if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
        echo -e "${RED}❌ Invalid YAML: $file${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Valid YAML: $file${NC}"
    return 0
}

# Function to validate Kubernetes manifest structure
validate_k8s_manifest() {
    local file=$1
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Check for required Kubernetes fields
    if ! grep -q "apiVersion:" "$file" || ! grep -q "kind:" "$file"; then
        echo -e "${RED}❌ Invalid K8s manifest (missing apiVersion/kind): $file${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Valid K8s manifest: $file${NC}"
    return 0
}

echo ""
echo "=== Testing Hot Cluster Manifests ==="
for file in k8s/cluster-hot/*.yaml; do
    if [ -f "$file" ]; then
        validate_yaml "$file" || ((ERRORS++))
        validate_k8s_manifest "$file" || ((ERRORS++))
    fi
done

echo ""
echo "=== Testing Standby Cluster Manifests ==="
for file in k8s/cluster-standby/*.yaml; do
    if [ -f "$file" ]; then
        validate_yaml "$file" || ((ERRORS++))
        validate_k8s_manifest "$file" || ((ERRORS++))
    fi
done

echo ""
echo "=== Testing Ingress Manifests ==="
for file in k8s/ingress/*.yaml; do
    if [ -f "$file" ]; then
        validate_yaml "$file" || ((ERRORS++))
        validate_k8s_manifest "$file" || ((ERRORS++))
    fi
done

echo ""
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All manifests are valid!${NC}"
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS error(s)${NC}"
    exit 1
fi

