Quick Summary:
Phase 1:

Install eksctl, kubectl, helm
Create cluster
Enable OIDC
Set variables

Phase 2: Load Balancer Controller 

Create IAM policy
Create service account
Install controller

Phase 3:

Create namespace
Create Fargate profile
Create nginx-app.yaml
Deploy!

To create and interact with Cluster we will need some cli tools
1. aws-cli (If working in cloudshell, not needed cos already configured)
2. eksctl - CLI tool for creating/managing EKS clusters
3.kubectl- Kubernetes command-line tool to interact with the cluster
helm - Kubernetes package manager 


** Install Cli Tools **
# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

command 2:
sudo mv /tmp/eksctl /usr/local/bin

# Verify eksctl
eksctl version

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify kubectl
kubectl version --client

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify Helm
helm version
