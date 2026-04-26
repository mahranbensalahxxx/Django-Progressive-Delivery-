#!/bin/bash
# =============================================================================
# Student 1: Canary Deployment Script
# Deploys Argo Rollout canary strategy for progressive traffic shifting.
# =============================================================================

set -euo pipefail

NAMESPACE="progressive-django"

echo "============================================="
echo "  Canary Deployment — Argo Rollouts"
echo "============================================="

# 1. Ensure Argo Rollouts is installed
echo "[1/4] Checking Argo Rollouts installation..."
if ! kubectl get namespace argo-rollouts &>/dev/null; then
    echo "  → Installing Argo Rollouts..."
    kubectl create namespace argo-rollouts
    kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
    echo "  → Waiting for Argo Rollouts controller..."
    kubectl rollout status deployment/argo-rollouts -n argo-rollouts --timeout=120s
else
    echo "  → Argo Rollouts already installed."
fi

# 2. Apply the analysis template
echo "[2/4] Applying AnalysisTemplate (health check config)..."
kubectl apply -f k8s/analysis-template.yaml -n "$NAMESPACE"

# 3. Deploy the Canary Rollout
echo "[3/4] Deploying Canary Rollout..."
kubectl apply -f k8s/rollout-canary.yaml -n "$NAMESPACE"

# 4. Monitor
echo "[4/4] Monitoring rollout status..."
echo "  → Run: kubectl argo rollouts get rollout django-rollout -n $NAMESPACE --watch"
echo "  → Promote: kubectl argo rollouts promote django-rollout -n $NAMESPACE"
echo ""
echo "To trigger canary update, change image to django-progressive:v2:"
echo "  kubectl argo rollouts set image django-rollout django=django-progressive:v2 -n $NAMESPACE"
echo ""
echo "============================================="
echo "  Canary deployment applied successfully!"
echo "============================================="
