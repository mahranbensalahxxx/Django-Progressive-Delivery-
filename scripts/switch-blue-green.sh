#!/bin/bash
# =============================================================================
# Student 2: Blue-Green Switch Script
# Switches traffic between Blue (v1) and Green (v2) deployments.
# Zero-downtime deployment by patching the Service selector.
# =============================================================================

set -euo pipefail

NAMESPACE="progressive-django"
SERVICE_NAME="django-service"

echo "============================================="
echo "  Blue-Green Deployment Switch"
echo "============================================="

# Get current active version
CURRENT=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "unknown")
echo "Current active version: $CURRENT"

if [ "$CURRENT" == "blue" ]; then
    TARGET="green"
    echo "Switching traffic: Blue (v1) → Green (v2)"
elif [ "$CURRENT" == "green" ]; then
    TARGET="blue"
    echo "Switching traffic: Green (v2) → Blue (v1)"
else
    echo "ERROR: Unknown current version '$CURRENT'. Defaulting to blue."
    TARGET="blue"
fi

# Apply Blue and Green deployments (ensure both are running)
echo ""
echo "[1/3] Ensuring both deployments are running..."
kubectl apply -f k8s/blue-deployment.yaml -n "$NAMESPACE"
kubectl apply -f k8s/green-deployment.yaml -n "$NAMESPACE"

# Wait for target deployment to be ready
echo "[2/3] Waiting for $TARGET deployment to be ready..."
kubectl rollout status deployment/django-$TARGET -n "$NAMESPACE" --timeout=120s

# Patch the service selector
echo "[3/3] Patching service selector to '$TARGET'..."
kubectl patch service "$SERVICE_NAME" -n "$NAMESPACE" \
    -p "{\"spec\":{\"selector\":{\"version\":\"$TARGET\"}}}"

echo ""
echo "============================================="
echo "  Traffic switched to $TARGET — Zero downtime!"
echo "============================================="
echo ""
echo "Verify: kubectl get service $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.selector.version}'"
echo "Test:   curl \$(minikube service $SERVICE_NAME -n $NAMESPACE --url)"
