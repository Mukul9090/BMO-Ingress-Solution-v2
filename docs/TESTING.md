# Testing Guide

This document describes the automated testing infrastructure for the BMO Ingress Solution.

## Test Suite Overview

The project includes comprehensive automated tests that run as part of the CI/CD pipeline:

1. **Unit Tests** - Test the Flask application endpoints
2. **Kubernetes Manifest Validation** - Validate all K8s YAML files
3. **Deployment Script Validation** - Check deployment scripts for syntax errors
4. **Docker Build Test** - Verify Docker image builds successfully
5. **Post-Deployment Health Checks** - Verify deployments are healthy

## Running Tests Locally

### Unit Tests

Test the Flask application:

```bash
# Run all unit tests
python -m unittest test_server -v

# Or run directly
python test_server.py
```

### Kubernetes Manifest Validation

Validate all Kubernetes manifests:

```bash
chmod +x test_kubernetes_manifests.sh
./test_kubernetes_manifests.sh
```

This checks:
- YAML syntax validity
- Kubernetes manifest structure (apiVersion, kind)
- All manifests in `k8s/cluster-hot/`, `k8s/cluster-standby/`, and `k8s/ingress/`

### Deployment Script Validation

Validate deployment scripts:

```bash
chmod +x test_deployment_scripts.sh
./test_deployment_scripts.sh
```

This checks:
- Script syntax (bash -n)
- Required scripts exist
- Scripts are executable

### Docker Build Test

Test that the Docker image builds:

```bash
docker build -t backend-service:test .
```

### Post-Deployment Health Checks

After deployment, verify everything is working:

```bash
# Set up kubeconfig first
export KUBECONFIG=~/.kube/config-hot

# Run health checks
chmod +x test_post_deployment.sh
./test_post_deployment.sh
```

This checks:
- Pods are running and ready
- Services have endpoints
- Ingress controller is running
- HTTP endpoints are accessible (if reachable)

## CI/CD Integration

Tests run automatically in GitHub Actions before deployment:

1. **Test Job** - Runs all validation tests
   - Unit tests
   - Manifest validation
   - Script validation
   - Docker build test

2. **Deploy Job** - Only runs if tests pass
   - Builds and pushes Docker image
   - Deploys to clusters
   - Runs post-deployment health checks

## Test Files

- `test_server.py` - Unit tests for Flask application
- `test_kubernetes_manifests.sh` - K8s manifest validation
- `test_deployment_scripts.sh` - Deployment script validation
- `test_post_deployment.sh` - Post-deployment health checks

## Adding New Tests

### Adding Unit Tests

Add test methods to `test_server.py`:

```python
def test_new_endpoint(self):
    """Test a new endpoint."""
    response = self.app.get('/new-endpoint')
    self.assertEqual(response.status_code, 200)
```

### Adding Manifest Tests

Update `test_kubernetes_manifests.sh` to include new manifest paths or validation rules.

### Adding Health Checks

Update `test_post_deployment.sh` to add new health check functions.

## Troubleshooting

### Tests Fail in CI/CD

- Check that all required files exist
- Verify Python dependencies are installed
- Ensure test scripts are executable (`chmod +x`)

### Post-Deployment Checks Fail

- This is normal if clusters are not directly accessible from GitHub Actions
- Health checks are non-blocking and will show warnings
- Verify deployments manually if needed

### Unit Tests Fail

- Ensure Flask and dependencies are installed: `pip install -r requirements.txt`
- Check that `server.py` is in the same directory
- Verify Python version (3.11+)

## Best Practices

1. **Run tests before committing** - Catch issues early
2. **Keep tests updated** - Update tests when adding new features
3. **Test locally first** - Verify tests work before pushing
4. **Review test output** - Check for warnings and errors

