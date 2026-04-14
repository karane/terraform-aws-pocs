# eks-cluster-poc

Deploy an EKS cluster with a managed node group on AWS using Terraform.

## What it creates

- EKS cluster (control plane) with control plane logging enabled
- Managed node group with auto-scaling (default: 2× `t3.medium`)
- IAM role for the cluster (`eks.amazonaws.com`)
- IAM role for worker nodes with `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`
- Security group for the cluster
- CloudWatch log group for control plane logs (`api`, `audit`, `authenticator`)

## Pre-requisites

- Terraform >= 1.0
- AWS CLI configured with sufficient permissions
- `kubectl` installed

## Setup AWS credentials

```bash
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_DEFAULT_REGION=us-east-2
```

## Deploy

```bash
terraform init
terraform apply
```

> EKS cluster creation takes ~10-15 minutes.

## Configure kubectl

After apply completes, run the output command to configure kubectl:

```bash
terraform output -raw kubeconfig_command | bash
```

Or manually:

```bash
aws eks update-kubeconfig --region us-east-2 --name eks-cluster-poc
```

## Verify

```bash
# Check nodes are Ready
kubectl get nodes

# Check system pods are running
kubectl get pods -n kube-system
```

## Deploy a test pod

```bash
kubectl run nginx --image=nginx --port=80
kubectl get pods
kubectl delete pod nginx
```

## View control plane logs

```bash
aws logs tail /aws/eks/eks-cluster-poc/cluster --follow
```

## Cleanup

```bash
terraform destroy
```
