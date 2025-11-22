#!/bin/bash
set -euo pipefail

### -------------------------------
### CONFIGURATION
### -------------------------------
CLUSTER_NAME="my-fargate-cluster"
AWS_REGION="us-east-1"
NAMESPACE="nginx-app"
FARGATE_PROFILE="nginx-profile"
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
SERVICE_ACCOUNT_NAME="aws-load-balancer-controller"
ROLE_NAME="AmazonEKSLoadBalancerControllerRole"

echo "=== Starting EKS Fargate deployment ==="

### -------------------------------
### STEP 1 — CREATE CLUSTER
### -------------------------------
echo "=== Creating EKS Fargate cluster ==="
eksctl create cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --fargate

echo "=== Cluster created successfully ==="
kubectl get svc

### -------------------------------
### STEP 2 — ENABLE OIDC
### -------------------------------
echo "=== Enabling IAM OIDC Provider ==="
eksctl utils associate-iam-oidc-provider \
  --cluster "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --approve

### -------------------------------
### STEP 3 — SET ENV VARIABLES
### -------------------------------
echo "=== Setting environment variables ==="
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
          --query "cluster.resourcesVpcConfig.vpcId" --output text)

echo "Cluster:   $CLUSTER_NAME"
echo "Region:    $AWS_REGION"
echo "Account:   $ACCOUNT_ID"
echo "VPC:       $VPC_ID"

### -------------------------------
### STEP 4 — IAM POLICY
### -------------------------------
echo "=== Creating IAM policy for Load Balancer Controller ==="
curl -so iam_policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name "$POLICY_NAME" \
  --policy-document file://iam_policy.json 2>/dev/null || echo "Policy already exists, continuing..."

### -------------------------------
### STEP 5 — CREATE IAM SERVICE ACCOUNT (IRSA)
### -------------------------------
echo "=== Creating IAM Service Account (IRSA) ==="
eksctl create iamserviceaccount \
  --cluster="$CLUSTER_NAME" \
  --namespace="kube-system" \
  --name="$SERVICE_ACCOUNT_NAME" \
  --role-name "$ROLE_NAME" \
  --attach-policy-arn="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME" \
  --approve \
  --region "$AWS_REGION"

### -------------------------------
### STEP 6 — INSTALL AWS LOAD BALANCER CONTROLLER
### -------------------------------
echo "=== Installing AWS Load Balancer Controller ==="
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name="$SERVICE_ACCOUNT_NAME" \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID"

echo "=== Waiting for AWS Load Balancer Controller to be ready ==="
echo "This may take 1-2 minutes..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/aws-load-balancer-controller -n kube-system

echo "=== Controller is ready! ==="
kubectl get deployment -n kube-system aws-load-balancer-controller

### -------------------------------
### STEP 7 — CREATE NAMESPACE
### -------------------------------
echo "=== Creating namespace $NAMESPACE ==="
kubectl create namespace "$NAMESPACE" 2>/dev/null || echo "Namespace already exists, continuing..."

### -------------------------------
### STEP 8 — CREATE FARGATE PROFILE
### -------------------------------
echo "=== Creating Fargate Profile ==="
eksctl create fargateprofile \
  --cluster "$CLUSTER_NAME" \
  --name "$FARGATE_PROFILE" \
  --namespace "$NAMESPACE" \
  --region "$AWS_REGION"

### -------------------------------
### STEP 9 — DEPLOY APPLICATION
### -------------------------------
echo "=== Checking for nginx-app.yaml ==="
if [ ! -f nginx-app.yaml ]; then
  echo "ERROR: nginx-app.yaml not found in current directory!"
  echo "Please make sure nginx-app.yaml is in the same directory as this script."
  exit 1
fi

echo "=== Deploying nginx application ==="
kubectl apply -f nginx-app.yaml

### -------------------------------
### STEP 10 — WAIT FOR PODS
### -------------------------------
echo "=== Waiting for pods to be ready ==="
echo "This takes 60-90 seconds on Fargate..."
kubectl wait --for=condition=ready pod -l app=eks-sample-linux-app -n "$NAMESPACE" --timeout=300s

echo "=== All pods are ready! ==="
kubectl get pods -n "$NAMESPACE"

### -------------------------------
### STEP 11 — GET LOAD BALANCER URL
### -------------------------------
echo "=== Waiting for Load Balancer to provision ==="
echo "This takes 2-3 minutes..."

for i in {1..60}; do
  EXTERNAL_IP=$(kubectl get svc eks-sample-linux-service -n "$NAMESPACE" \
                -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  
  if [ ! -z "$EXTERNAL_IP" ]; then
    echo ""
    echo "========================================="
    echo " DEPLOYMENT SUCCESSFUL! "
    echo "========================================="
    echo ""
    echo "Your nginx app is live at:"
    echo "  http://$EXTERNAL_IP"
    echo ""
    echo "Test it with:"
    echo "  curl http://$EXTERNAL_IP"
    echo ""
    echo "Or open in your browser!"
    echo ""
    echo "========================================="
    echo ""
    echo "Useful commands:"
    echo "  kubectl get all -n $NAMESPACE"
    echo "  kubectl get pods -n $NAMESPACE"
    echo "  kubectl logs -n $NAMESPACE -l app=eks-sample-linux-app"
    echo "  kubectl scale deployment eks-sample-linux-deployment -n $NAMESPACE --replicas=5"
    echo ""
    echo "Verify Load Balancer type (should be 'network'):"
    echo "  aws elbv2 describe-load-balancers --region $AWS_REGION --query \"LoadBalancers[?contains(LoadBalancerName, 'k8s-nginxapp')].Type\" --output text"
    echo ""
    echo "========================================="
    exit 0
  fi
  
  echo -n "."
  sleep 5
done

echo ""
echo "  Timeout waiting for Load Balancer. Check status manually with:"
echo "  kubectl get svc -n $NAMESPACE"
echo "  kubectl describe svc eks-sample-linux-service -n $NAMESPACE"
exit 1
