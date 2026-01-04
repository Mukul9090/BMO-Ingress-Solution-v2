# Push to GitHub - Quick Guide

## Your code is committed! ✅

Commit hash: `63ddab8`

## Next Steps to Push to GitHub

### Option 1: If you already have a GitHub repository

```bash
# Add your remote (replace with your actual repo URL)
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git

# Push to GitHub
git push -u origin main
```

### Option 2: Create a new GitHub repository

1. Go to https://github.com/new
2. Create a new repository (name it something like `bmo-ingress-solution`)
3. **Don't** initialize with README (you already have one)
4. Copy the repository URL
5. Run these commands:

```bash
# Add remote (replace with your actual repo URL)
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git

# Push to GitHub
git push -u origin main
```

### Option 3: Using SSH (if you have SSH keys set up)

```bash
# Add remote with SSH
git remote add origin git@github.com:YOUR_USERNAME/YOUR_REPO_NAME.git

# Push to GitHub
git push -u origin main
```

## After Pushing

### 1. Set up GitHub Secrets

Go to your repository: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these secrets:

**KUBECONFIG_HOT:**
```bash
kubectl config view --flatten | base64
# Copy output and paste as secret
```

**KUBECONFIG_STANDBY:**
```bash
# Switch to standby cluster first
kubectl config use-context <your-standby-context>
kubectl config view --flatten | base64
# Copy output and paste as secret
```

### 2. Verify Runner

Make sure your **BMO-platform** runner is:
- Registered with your repository
- Online and ready
- Has Docker and kubectl installed

### 3. Test the Workflow

- Push any change to `main` branch to trigger automatic deployment
- Or go to **Actions** tab → **🚀 Deploy to Kubernetes** → **Run workflow**

## That's it! 🎉

Your single workflow will automatically:
1. Build Docker image
2. Push to GHCR
3. Deploy to Hot Cluster
4. Deploy to Standby Cluster
5. Deploy Ingress

All in one simple workflow!

