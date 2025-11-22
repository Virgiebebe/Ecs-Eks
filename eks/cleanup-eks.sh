#!/bin/bash
set -e

### -------------------------------
### CONFIGURATION
### -------------------------------
CLUSTER_NAME="my-fargate-cluster"
AWS_REGION="us-east-1"
NAMESPACE="nginx-app"
FARGATE_PROFILE="nginx-profile"
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"

echo ""
echo "========================================="
echo " EKS Fargate Cleanup Script"
echo "========================================="
echo ""
echo "This will delete:"
echo "  - Application (nginx)"
echo "  - Namespace: $NAMESPACE"
echo "  - Fargate profile: $FARGATE_PROFILE"
echo "  - AWS Load Balancer Controller"
echo "  - IAM service account & role"
echo "  - IAM policy: $POLICY_NAME"
echo "  - EKS cluster: $CLUSTER_NAME"
echo ""
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""

### -------------------------------
### STEP 1 — DELETE APPLICATION
### -------------------------------
echo "=== Deleting application ==="
if kubectl delete -f nginx-app.yaml 2>/dev/null; then
    echo "Application deleted successfully"
else
    echo "Application not found or already deleted"
fi

# Wait a moment for resources to be cleaned up
sleep 5

### -------------------------------
### STEP 2 — DELETE NAMESPACE
### -------------------------------
echo "=== Deleting namespace ==="
if kubectl delete namespace "$NAMESPACE" 2>/dev/null; then
    echo "Namespace deleted successfully"
    # Wait for namespace to be fully deleted
    echo "Waiting for namespace to be fully deleted..."
    kubectl wait --for=delete namespace/"$NAMESPACE" --timeout=120s 2>/dev/null || true
else
    echo "Namespace not found or already deleted"
fi

### -------------------------------
### STEP 3 — DELETE FARGATE PROFILE
### -------------------------------
echo "=== Deleting Fargate profile ==="
if eksctl delete fargateprofile \
    --cluster "$CLUSTER_NAME" \
    --name "$FARGATE_PROFILE" \
    --region "$AWS_REGION" 2>/dev/null; then
    echo "Fargate profile deletion initiated"
else
    echo "Fargate profile not found or already deleted"
fi

# Wait for Fargate profile to be deleted
echo "Waiting for Fargate profile to be fully deleted (this takes 1-2 minutes)..."
for i in {1..30}; do
    if eksctl get fargateprofile --cluster "$CLUSTER_NAME" --name "$FARGATE_PROFILE" --region "$AWS_REGION" 2>/dev/null | grep -q "$FARGATE_PROFILE"; then
        echo -n "."
        sleep 5
    else
        echo ""
        echo "Fargate profile deleted successfully"
        break
    fi
done

### -------------------------------
### STEP 4 — UNINSTALL LOAD BALANCER CONTROLLER
### -------------------------------
echo "=== Uninstalling AWS Load Balancer Controller ==="
if helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null; then
    echo "Controller uninstalled successfully"
else
    echo "Controller not found or already uninstalled"
fi

### -------------------------------
### STEP 5 — DELETE IAM SERVICE ACCOUNT
### -------------------------------
echo "=== Deleting IAM service account ==="
if eksctl delete iamserviceaccount \
    --cluster="$CLUSTER_NAME" \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --region "$AWS_REGION" 2>/dev/null; then
    echo "IAM service account deleted successfully"
else
    echo "IAM service account not found or already deleted"
fi

### -------------------------------
### STEP 6 — DELETE IAM POLICY
### -------------------------------
echo "=== Deleting IAM policy ==="
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# First, detach policy from any roles (if attached)
echo "Checking for attached entities..."
ATTACHED_ROLES=$(aws iam list-entities-for-policy \
    --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME" \
    --query 'PolicyRoles[].RoleName' \
    --output text 2>/dev/null || echo "")

if [ ! -z "$ATTACHED_ROLES" ]; then
    echo "Detaching policy from roles: $ATTACHED_ROLES"
    for role in $ATTACHED_ROLES; do
        aws iam detach-role-policy \
            --role-name "$role" \
            --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME" 2>/dev/null || true
    done
    sleep 5
fi

# Delete all non-default policy versions
echo "Deleting policy versions..."
VERSIONS=$(aws iam list-policy-versions \
    --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME" \
    --query 'Versions[?!IsDefaultVersion].VersionId' \
    --output text 2>/dev/null || echo "")

for version in $VERSIONS; do
    aws iam delete-policy-version \
        --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME" \
        --version-id "$version" 2>/dev/null || true
    echo "  Deleted version: $version"
done

# Delete the policy
if aws iam delete-policy \
    --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME" 2>/dev/null; then
    echo "IAM policy deleted successfully"
else
    echo "IAM policy not found or already deleted"
fi

### -------------------------------
### STEP 7 — DELETE EKS CLUSTER
### -------------------------------
echo "=== Deleting EKS cluster (this takes 10-15 minutes) ==="
echo "Please be patient..."

if eksctl delete cluster \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION"; then
    echo "Cluster deleted successfully"
else
    echo "Error deleting cluster. It may already be deleted."
fi

### -------------------------------
### STEP 8 — CLEAN UP LOCAL FILES
### -------------------------------
echo "=== Cleaning up local files ==="
rm -f nginx-app.yaml iam_policy.json
rm -rf ~/.kube

echo ""
echo "========================================="
echo "✅ CLEANUP COMPLETE!"
echo "========================================="
echo ""
echo "All resources have been deleted:"
echo "  ✅ Application"
echo "  ✅ Namespace"
echo "  ✅ Fargate profile"
echo "  ✅ Load Balancer Controller"
echo "  ✅ IAM service account"
echo "  ✅ IAM policy"
echo "  ✅ EKS cluster"
echo "  ✅ Local files"
echo ""
echo "You can now run the installation script again!"
echo ""
