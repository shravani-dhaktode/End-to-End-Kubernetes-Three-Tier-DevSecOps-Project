#!/bin/bash
# STEP: create the Kubernetes (EKS) cluster + AWS Load Balancer Controller + ArgoCD.
# Run on the Jenkins server as user "ubuntu", from inside the project folder:
#     nohup bash scripts/1-create-eks.sh > eks-setup.log 2>&1 &
#     tail -f eks-setup.log
# Takes about 20-25 minutes. The last line says "ALL DONE".
set -euo pipefail

CLUSTER=three-tier-cluster
REGION=us-east-1
ACCOUNT_ID=747456040606

echo "===== [1/4] Creating EKS cluster '$CLUSTER' (15-20 minutes, please wait) ====="
if eksctl get cluster --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1; then
  echo "Cluster already exists - skipping creation."
else
  eksctl create cluster \
    --name "$CLUSTER" \
    --region "$REGION" \
    --zones us-east-1a,us-east-1b \
    --nodegroup-name app-nodes \
    --managed \
    --instance-types c7i-flex.large \
    --nodes 2 --nodes-min 2 --nodes-max 3 \
    --with-oidc
fi
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"
kubectl get nodes

echo "===== [2/4] Installing AWS Load Balancer Controller ====="
curl -sSo /tmp/iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file:///tmp/iam_policy.json >/dev/null 2>&1 \
  || echo "IAM policy already exists - OK"

eksctl create iamserviceaccount \
  --cluster "$CLUSTER" --region "$REGION" \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy" \
  --override-existing-serviceaccounts \
  --approve

helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" --region "$REGION" --query "cluster.resourcesVpcConfig.vpcId" --output text)
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="$REGION" \
  --set vpcId="$VPC_ID" \
  --set replicaCount=1
kubectl -n kube-system rollout status deployment aws-load-balancer-controller --timeout=300s

echo "===== [3/4] Installing ArgoCD ====="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deployment argocd-server --timeout=600s

echo "===== [4/4] Giving ArgoCD a public web address ====="
kubectl annotate svc argocd-server -n argocd --overwrite \
  service.beta.kubernetes.io/aws-load-balancer-type=external \
  service.beta.kubernetes.io/aws-load-balancer-scheme=internet-facing \
  service.beta.kubernetes.io/aws-load-balancer-nlb-target-type=ip
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

echo "Waiting for the ArgoCD address..."
ARGO_URL=""
for i in $(seq 1 30); do
  ARGO_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  [ -n "$ARGO_URL" ] && break
  sleep 10
done
ARGO_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "================================================================"
echo " ALL DONE"
echo " ArgoCD URL : https://$ARGO_URL   (wait 3-5 min for it to open; click Advanced > Proceed)"
echo " Username   : admin"
echo " Password   : $ARGO_PASS"
echo "================================================================"
