#!/bin/bash
# STEP: tell ArgoCD to deploy the app, then print the website address.
# Run AFTER both Jenkins pipelines (frontend + backend) have finished successfully.
#     bash scripts/2-deploy-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

kubectl apply -f argocd/application.yaml
echo "ArgoCD is deploying the app. Waiting for the pods..."
sleep 30
for i in $(seq 1 30); do
  kubectl get pods -n three-tier 2>/dev/null || true
  READY=$(kubectl get pods -n three-tier --no-headers 2>/dev/null | grep -c "1/1" || true)
  [ "$READY" -ge 3 ] && break
  sleep 10
done

echo "Waiting for the load balancer address (2-4 minutes)..."
APP_URL=""
for i in $(seq 1 40); do
  APP_URL=$(kubectl get ingress mainlb -n three-tier -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  [ -n "$APP_URL" ] && break
  sleep 10
done

echo ""
echo "================================================================"
echo " Your app: http://$APP_URL"
echo " (If it does not open yet, wait 2-3 more minutes and refresh.)"
echo "================================================================"
