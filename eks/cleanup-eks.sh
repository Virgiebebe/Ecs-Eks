#!/bin/bash
set -e

echo "=== Deleting application ==="
kubectl delete -f nginx-app.yaml || echo "nginx-app.yaml not found or already deleted"

echo "=== Deleting namespace ==="
kubectl delete namespace nginx-app || echo "Namespace already deleted"

echo "=== Deleting Fargate profile ==="
eksctl delete fargateprofile \
  --cluster my-fargate-cluster \
  --name nginx-profile \
  --region us-east-1 || echo "Fargate profile may already be deleted"

echo "=== Uninstalling AWS Load Balancer Controller ==="
helm uninstall aws-load-balancer-controller -n kube-system || echo "Controller already removed"

echo "=== Deleting IAM service account ==="
eksctl delete iamserviceaccount \
  --cluster=my-fargate-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --region us-east-1 || echo "IAM service account already deleted"

echo "=== Deleting IAM policy ==="
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws iam delete-policy \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  || echo "IAM policy already deleted"

echo "=== Deleting EKS cluster (this takes 10–15 mins) ==="
eksctl delete cluster \
  --name my-fargate-cluster \
  --region us-east-1

echo "=== Cleaning up local files ==="
rm -f nginx-app.yaml iam_policy.json
rm -rf ~/.kube

echo "=== Cleanup Complete ==="
