# Load Balancer Test Dashboard - Usage Guide

## Quick Start

The `loadbalancer-test.html` file is a web-based dashboard for testing your load balancer and failover setup.

## Prerequisites Setup

### 1. NodePort Services (Already Created ✅)
- Hot cluster: Port 31080
- Standby cluster: Port 31081

### 2. Port Forward for Ingress (Already Running ✅)
```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

### 3. /etc/hosts Entry (Already Configured ✅)
```
192.168.49.2 backend.local
```

### 4. HTTP Server (Already Running ✅)
The dashboard is being served at:   

## How to Use

### Step 1: Open the Dashboard
Open your browser and navigate to:
```
http://localhost:8000/loadbalancer-test.html
```

### Step 2: Test Individual Clusters
1. **Test Hot Cluster**: Click "🔄 Test Hot Cluster" button
   - This tests the hot cluster directly on port 31080
   - Should show cluster role: "hot"

2. **Test Standby Cluster**: Click "🔄 Test Standby Cluster" button
   - This tests the standby cluster directly on port 31081
   - Should show cluster role: "standby"

### Step 3: Test Load Balancer
1. **Single Test**: Click "🔄 Test Load Balancer" button
   - Tests the ingress controller on port 8080
   - Shows which cluster (hot or standby) responded
   - Displays full JSON response

2. **Multiple Tests**: Click "🔄 Test Multiple Requests (10x)" button
   - Sends 10 requests to the load balancer
   - Shows distribution between hot and standby clusters
   - Useful for testing load balancing behavior

3. **Auto Test**: Click "▶️ Start Auto Test" button
   - Continuously tests the load balancer every 2 seconds
   - Toggle the switch in "Auto Test Configuration" to enable/disable
   - Adjust interval (1-10 seconds) as needed

### Step 4: Test Failover
1. **Simulate Hot Cluster Failure**:
   ```bash
   kubectl scale deployment backend-service -n cluster-hot --replicas=0
   ```
   Then test the load balancer - it should route to standby!

2. **Restore Hot Cluster**:
   ```bash
   kubectl scale deployment backend-service -n cluster-hot --replicas=3
   ```
   Then test again - both clusters should be available!

## Dashboard Features

### Statistics Panel
- **Total Requests**: Count of all requests sent
- **Hot Cluster**: Number of responses from hot cluster
- **Standby Cluster**: Number of responses from standby cluster
- **Success Rate**: Percentage of successful requests

### Activity Log
- Real-time log of all test activities
- Color-coded: green (success), red (error), blue (info)
- Shows timestamps for each event

### Architecture Diagram
- Visual representation of the setup
- Shows request flow from browser → Ingress → Clusters

## Troubleshooting

### CORS Errors
If you see CORS errors, make sure you're accessing the HTML file via HTTP (http://localhost:8000/...) and NOT via file:// protocol.

### Connection Errors
1. **Load Balancer (Port 8080)**:
   ```bash
   # Check if port-forward is running
   ps aux | grep "kubectl port-forward.*8080"
   
   # Restart if needed
   kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
   ```

2. **Hot Cluster (Port 31080)**:
   ```bash
   # Test directly
   curl http://localhost:31080/healthz
   
   # Check service
   kubectl get svc -n cluster-hot
   ```

3. **Standby Cluster (Port 31081)**:
   ```bash
   # Test directly
   curl http://localhost:31081/healthz
   
   # Check service
   kubectl get svc -n cluster-standby
   ```

### Ingress Not Working
```bash
# Check ingress status
kubectl get ingress -n default

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Verify /etc/hosts entry
cat /etc/hosts | grep backend.local
```

## Manual Testing (Alternative)

If the dashboard doesn't work, you can test manually:

```bash
# Test load balancer
curl -H "Host: backend.local" http://localhost:8080/healthz

# Test hot cluster directly
curl http://localhost:31080/healthz

# Test standby cluster directly
curl http://localhost:31081/healthz
```

## Stopping Services

To stop the background services:

```bash
# Stop HTTP server
pkill -f "python3 -m http.server 8000"

# Stop port-forward
pkill -f "kubectl port-forward.*8080"
```

