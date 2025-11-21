Step 1: install cluster
# Create cluster (takes 15-20 minutes)
eksctl create cluster \
  --name my-fargate-cluster \
  --region us-east-1 \
  --fargate

Wait for
  [✔]  EKS cluster "my-fargate-cluster" in "us-east-1" region is ready

Verify:
eksctl get cluster --region us-east-1
kubectl get svc

Step 2: 
# Enable OIDC (required for Load Balancer Controller)
eksctl utils associate-iam-oidc-provider \
  --cluster my-fargate-cluster \
  --region us-east-1 \
  --approve

  [✔]  created IAM Open ID Connect provider for cluster "my-fargate-cluster"

Step 3:
# Setup Environment Variables
export CLUSTER_NAME="my-fargate-cluster"
export AWS_REGION="us-east-1"
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)

# Verify variables
echo "✅ Cluster: $CLUSTER_NAME"
echo "✅ Region: $AWS_REGION"
echo "✅ Account: $ACCOUNT_ID"
echo "✅ VPC: $VPC_ID"

Step 4:
# Create IAM Policy for Load Balancer Controller
# Download the latest IAM policy (Skip if policy already exits)
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

# Create the policy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

Step 5:
# Create IAM Service Account    
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region $AWS_REGION

Step 6:
# Install AWS Load Balancer Controller
# Add EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install the controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID


Verify installation:
  kubectl get deployment -n kube-system aws-load-balancer-controller

Step 7:

# Create namespace for your app
kubectl create namespace nginx-app

# Verify
kubectl get namespaces

Step 8:
Create Fargate Profile:
# Create Fargate profile for nginx-app namespace
eksctl create fargateprofile \
  --cluster my-fargate-cluster \
  --name nginx-profile \
  --namespace nginx-app \
  --region us-east-1

Wait for:
[✔]  created Fargate profile "nginx-profile" on EKS cluster "my-fargate-cluster"

Step 9:
Create Deployment
# Deploy everything
kubectl apply -f nginx-app.yaml

step 10 
# Watch pods
kubectl get pods -n nginx-app -w
