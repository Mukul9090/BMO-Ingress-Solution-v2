#!/bin/bash
# Test script to validate deployment scripts

set -e

echo "=== Testing Deployment Scripts ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Function to check if script is executable and has shebang
check_script() {
    local script=$1
    if [ ! -f "$script" ]; then
        echo -e "${YELLOW}⚠️  Script not found: $script${NC}"
        return 1
    fi
    
    # Check for shebang
    if ! head -1 "$script" | grep -q "^#!"; then
        echo -e "${RED}❌ Missing shebang: $script${NC}"
        return 1
    fi
    
    # Check if script is executable
    if [ ! -x "$script" ]; then
        echo -e "${YELLOW}⚠️  Script not executable: $script${NC}"
        chmod +x "$script"
        echo -e "${GREEN}✓ Made executable: $script${NC}"
    fi
    
    # Check for syntax errors (bash -n)
    if bash -n "$script" 2>/dev/null; then
        echo -e "${GREEN}✓ Valid syntax: $script${NC}"
        return 0
    else
        echo -e "${RED}❌ Syntax error: $script${NC}"
        return 1
    fi
}

echo ""
echo "=== Testing Deployment Scripts ==="
for script in deploy-*.sh; do
    if [ -f "$script" ]; then
        check_script "$script" || ((ERRORS++))
    fi
done

# Check for required scripts
REQUIRED_SCRIPTS=("deploy-cluster-hot.sh" "deploy-cluster-standby.sh" "deploy-ingress.sh" "deploy-all.sh")
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        echo -e "${RED}❌ Required script missing: $script${NC}"
        ((ERRORS++))
    fi
done

echo ""
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All deployment scripts are valid!${NC}"
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS error(s)${NC}"
    exit 1
fi

