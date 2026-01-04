# GitHub Actions CI/CD Setup

This project uses a single, simple GitHub Actions workflow for automated deployment.

## Quick Setup

### 1. Configure GitHub Secrets

Go to your repository: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these two secrets:

#### KUBECONFIG_HOT
```bash
# Get your hot cluster kubeconfig and encode it
kubectl config view --flatten | base64
# Copy the output and paste as KUBECONFIG_HOT secret
```

#### KUBECONFIG_STANDBY
```bash
# Switch to standby cluster context first
kubectl config use-context <your-standby-context>
kubectl config view --flatten | base64
# Copy the output and paste as KUBECONFIG_STANDBY secret
```

### 2. Verify Runner

Make sure your self-hosted runner **BMO-platform** is:
- ✅ Registered with your GitHub repository
- ✅ Online and ready
- ✅ Has Docker and kubectl installed

### 3. Push to Trigger Deployment

The workflow automatically runs when you:
- Push to `main` or `develop` branches
- Or manually trigger from **Actions** tab → **Run workflow**

## How It Works

The workflow (`.github/workflows/deploy.yml`) does everything in one job:

1. **Builds** Docker image
2. **Pushes** to GitHub Container Registry (GHCR)
3. **Deploys** to Hot Cluster
4. **Deploys** to Standby Cluster  
5. **Deploys** Ingress Controller

All in a single workflow! 🎉

## Manual Deployment

1. Go to **Actions** tab in GitHub
2. Click **🚀 Deploy to Kubernetes** workflow
3. Click **Run workflow** button
4. Select branch and click **Run workflow**

## Image Registry

Images are automatically pushed to:
- `ghcr.io/<your-username>/<repo>/backend-service:latest`
- `ghcr.io/<your-username>/<repo>/backend-service:<commit-sha>`

No additional registry setup needed - uses GitHub Container Registry with automatic authentication!

## Troubleshooting

### Runner Not Found
- Check runner is registered: **Settings** → **Actions** → **Runners**
- Verify runner name matches exactly: `BMO-platform`

### Deployment Fails
- Check kubeconfig secrets are valid
- Verify clusters are accessible from runner
- Check runner has kubectl and Docker installed

### Image Pull Errors
- Ensure image exists in GHCR
- Check deployment has imagePullSecrets configured (if needed)
- Verify GHCR permissions

## What Gets Deployed

- ✅ Hot cluster (3 replicas)
- ✅ Standby cluster (3 replicas)
- ✅ NGINX Ingress Controller
- ✅ All services and configmaps

Everything is automated - just push to main! 🚀

