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

echo "=== Waiting for cluster to be ready ==="
eksctl get cluster --region "$AWS_REGION"
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
echo "=== Creating IAM policy for ALB Controller ==="
curl -o iam_policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name "$POLICY_NAME" \
  --policy-document file://iam_policy.json || echo "Policy already exists."

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
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name="$SERVICE_ACCOUNT_NAME" \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID"

kubectl get deployment -n kube-system aws-load-balancer-controller

### -------------------------------
### STEP 7 — CREATE NAMESPACE
### -------------------------------
echo "=== Creating namespace $NAMESPACE ==="
kubectl create namespace "$NAMESPACE" || echo "Namespace already exists."

kubectl get namespaces

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
echo "=== Deploying nginx-app.yaml ==="
if [ ! -f nginx-app.yaml ]; then
  echo "ERROR: nginx-app.yaml not found!"
  exit 1
fi

kubectl apply -f nginx-app.yaml

### -------------------------------
### STEP 10 — WATCH PODS
### -------------------------------
echo "=== Watching pods in $NAMESPACE ==="
kubectl get pods -n "$NAMESPACE" -w
