# CI/CD with GitHub Actions

This project uses GitHub Actions for continuous integration and continuous deployment to both hot and standby Kubernetes clusters.

## Workflow Overview

The CI/CD pipeline (`ci-cd.yml`) includes the following stages:

1. **Test** - Run application tests and linting
2. **Validate Kubernetes Manifests** - Validate all K8s manifests
3. **Build and Push** - Build Docker image and push to GitHub Container Registry
4. **Deploy to Hot Cluster** - Deploy to the primary (hot) cluster
5. **Deploy to Standby Cluster** - Deploy to the standby cluster
6. **Deploy Ingress** - Configure NGINX Ingress for routing
7. **Notify** - Send deployment summary

## Triggers

The workflow runs on:
- **Push to main/develop branches** - Full CI/CD pipeline
- **Pull Requests** - CI only (test, validate, build - no deployment)
- **Manual dispatch** - Full pipeline with environment selection

## Required Secrets

Configure the following secrets in your GitHub repository settings:

### Kubernetes Cluster Access

1. **KUBECONFIG_HOT** - Base64-encoded kubeconfig for hot cluster
   ```bash
   # Get your kubeconfig and encode it
   cat ~/.kube/config | base64
   ```

2. **KUBECONFIG_STANDBY** - Base64-encoded kubeconfig for standby cluster
   ```bash
   # Get your kubeconfig and encode it
   cat ~/.kube/config-standby | base64
   ```

### Optional: Docker Registry (Alternative to GHCR)

If you want to use Docker Hub or another registry instead of GitHub Container Registry:

1. **DOCKER_USERNAME** - Docker registry username
2. **DOCKER_PASSWORD** - Docker registry password/token

## Setting Up Secrets

### Step 1: Get Kubeconfig Files

For each cluster, export the kubeconfig:

```bash
# Hot cluster
kubectl config view --flatten > kubeconfig-hot.yaml

# Standby cluster (switch context first)
kubectl config use-context <standby-context>
kubectl config view --flatten > kubeconfig-standby.yaml
```

### Step 2: Encode and Add to GitHub

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret:

```bash
# Encode the kubeconfig
cat kubeconfig-hot.yaml | base64
# Copy the output and paste as KUBECONFIG_HOT

cat kubeconfig-standby.yaml | base64
# Copy the output and paste as KUBECONFIG_STANDBY
```

## Image Registry

By default, the workflow uses **GitHub Container Registry (GHCR)**:
- Registry: `ghcr.io`
- Image: `ghcr.io/<username>/<repo>/backend-service`
- Authentication: Uses `GITHUB_TOKEN` (automatically provided)

### Using a Different Registry

To use Docker Hub or another registry:

1. Update the workflow file:
   ```yaml
   env:
     REGISTRY: docker.io
     IMAGE_NAME: <username>/backend-service
   ```

2. Add registry secrets:
   - `DOCKER_USERNAME`
   - `DOCKER_PASSWORD`

## Deployment Process

### Automatic Deployment

When you push to `main` branch:
1. Tests run
2. Docker image is built and tagged with commit SHA
3. Image is pushed to registry
4. Hot cluster is updated with new image
5. Standby cluster is updated with new image
6. Ingress configuration is applied

### Manual Deployment

You can trigger a manual deployment:

1. Go to **Actions** tab in GitHub
2. Select **CI/CD** workflow
3. Click **Run workflow**
4. Select:
   - **Environment**: dev, staging, or production
   - **Deploy to clusters**: both, hot, or standby

### Image Tagging Strategy

Images are tagged with:
- `latest` - Only on default branch (main)
- `<branch-name>-<sha>` - Branch-specific builds
- `<sha>` - Commit SHA
- Semantic version tags (if using tags)

## Workflow Jobs

### test
- Runs Python linter (flake8)
- Tests application with different cluster roles
- Validates health endpoints

### validate-k8s
- Validates all Kubernetes manifests
- Checks syntax and structure
- No actual deployment

### build-and-push
- Builds multi-arch Docker image (amd64, arm64)
- Pushes to GitHub Container Registry
- Uses build cache for faster builds

### deploy-hot
- Deploys to hot cluster
- Updates deployment with new image
- Waits for rollout to complete
- Verifies deployment

### deploy-standby
- Deploys to standby cluster
- Updates deployment with new image
- Waits for rollout to complete
- Verifies deployment

### deploy-ingress
- Applies Ingress resources
- Configures NGINX Ingress
- Sets up active-passive routing

### notify
- Creates deployment summary
- Shows deployment status
- Includes image tags and commit info

## Environment Protection

You can configure environment protection rules in GitHub:

1. Go to **Settings** → **Environments**
2. Create environments: `dev`, `staging`, `production`
3. Add required reviewers for production
4. Set deployment branches

## Monitoring Deployments

### View Deployment Status

1. Go to **Actions** tab
2. Click on the workflow run
3. View each job's logs
4. Check deployment summary

### Verify Deployment

After deployment, verify in your clusters:

```bash
# Hot cluster
kubectl get pods -n cluster-hot
kubectl get deployment -n cluster-hot

# Standby cluster
kubectl get pods -n cluster-standby
kubectl get deployment -n cluster-standby

# Ingress
kubectl get ingress
```

## Troubleshooting

### Build Fails

- Check Dockerfile syntax
- Verify all dependencies in requirements.txt
- Check build logs for specific errors

### Deployment Fails

- Verify kubeconfig secrets are correct
- Check cluster connectivity
- Ensure namespaces exist
- Check resource quotas

### Image Pull Errors

- Verify image exists in registry
- Check image pull secrets
- Ensure registry authentication

### Rollout Timeout

- Check pod logs: `kubectl logs -n cluster-hot <pod-name>`
- Verify health checks are passing
- Check resource limits

## Best Practices

1. **Always test in PRs** - PRs run CI but don't deploy
2. **Use semantic versioning** - Tag releases for better tracking
3. **Monitor deployments** - Check logs after each deployment
4. **Rollback strategy** - Keep previous image tags for quick rollback
5. **Environment separation** - Use different clusters/namespaces for dev/staging/prod

## Rollback

To rollback to a previous version:

```bash
# Get previous image tag
kubectl get deployment backend-service -n cluster-hot -o jsonpath='{.spec.template.spec.containers[0].image}'

# Rollback to previous revision
kubectl rollout undo deployment/backend-service -n cluster-hot
kubectl rollout undo deployment/backend-service -n cluster-standby
```

Or manually set image:

```bash
kubectl set image deployment/backend-service \
  backend-service=ghcr.io/<user>/<repo>/backend-service:<previous-tag> \
  -n cluster-hot
```

## Customization

### Change Registry

Edit `.github/workflows/ci-cd.yml`:

```yaml
env:
  REGISTRY: docker.io  # or your registry
  IMAGE_NAME: your-org/backend-service
```

### Add More Tests

Add test steps in the `test` job:

```yaml
- name: Run integration tests
  run: |
    pytest tests/
```

### Custom Deployment Strategy

Modify deployment jobs to use:
- Blue-green deployments
- Canary releases
- Feature flags

## Security

- **Secrets**: Never commit kubeconfig files or passwords
- **Image scanning**: Enable GitHub's Dependabot for vulnerability scanning
- **RBAC**: Use service accounts with minimal permissions
- **Network policies**: Restrict pod-to-pod communication

