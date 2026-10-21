#!/bin/bash
# STEP: delete the Kubernetes cluster and its load balancers so AWS stops charging.
# Run on the Jenkins server. Use it to PAUSE (then stop the EC2 instance) or before "terraform destroy".
#     bash scripts/3-cleanup.sh
# Takes about 10-15 minutes.
set -uo pipefail
cd "$(dirname "$0")/.."

CLUSTER=three-tier-cluster
REGION=us-east-1
ACCOUNT_ID=747456040606

echo "Removing ArgoCD app (so it does not re-create things)..."
kubectl delete -f argocd/application.yaml --ignore-not-found

echo "Deleting the app load balancer (ALB)..."
kubectl delete ingress mainlb -n three-tier --ignore-not-found --timeout=180s

echo "Deleting the ArgoCD load balancer (NLB)..."
kubectl delete svc argocd-server -n argocd --ignore-not-found --timeout=180s

echo "Waiting 60 seconds for AWS to remove the load balancers..."
sleep 60

echo "Deleting the EKS cluster (10-15 minutes)..."
eksctl delete cluster --name "$CLUSTER" --region "$REGION" --wait

echo "Deleting the Load Balancer Controller IAM policy..."
aws iam delete-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy" || true

echo ""
echo "Cluster deleted."
echo " - Pausing for exam day? Now STOP (not terminate) the Jenkins-server instance in the EC2 console."
echo " - Deleting forever? Now run 'terraform destroy' in CloudShell (README Part 14B)."
