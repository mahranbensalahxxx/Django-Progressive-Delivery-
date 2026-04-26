#!/bin/bash
# =============================================================================
# Student 3: Shadow Traffic Test Script
# Deploys NGINX shadow proxy and tests that traffic is mirrored to Green (v2).
# =============================================================================

set -euo pipefail

NAMESPACE="progressive-django"

echo "============================================="
echo "  Shadow Traffic — NGINX Mirror Test"
echo "============================================="

# 1. Deploy NGINX shadow components
echo "[1/4] Deploying NGINX shadow configuration..."
kubectl apply -f k8s/nginx-configmap.yaml -n "$NAMESPACE"
kubectl apply -f k8s/nginx-deployment.yaml -n "$NAMESPACE"
kubectl apply -f k8s/nginx-service.yaml -n "$NAMESPACE"

# 2. Wait for NGINX to be ready
echo "[2/4] Waiting for NGINX shadow proxy..."
kubectl rollout status deployment/nginx-shadow -n "$NAMESPACE" --timeout=120s

# 3. Port-forward to test
echo "[3/4] Setting up port-forward (localhost:8080 → NGINX shadow proxy)..."
kubectl port-forward service/nginx-shadow-service 8080:80 -n "$NAMESPACE" &
PF_PID=$!
sleep 3

# 4. Send test requests
echo "[4/4] Sending test requests through shadow proxy..."
echo ""
for i in $(seq 1 10); do
    echo "--- Request $i ---"
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" http://localhost:8080/)
    echo "$RESPONSE"
    echo ""
    sleep 1
done

# Cleanup port-forward
kill $PF_PID 2>/dev/null

echo "============================================="
echo "  Shadow traffic test complete!"
echo "============================================="
echo ""
echo "Check Green (v2) pod logs for mirrored requests:"
echo "  kubectl logs -l version=green -n $NAMESPACE --tail=20"
echo ""
echo "Look for requests with X-Shadow-Traffic header in Green pod logs."
