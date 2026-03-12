# AWS Fargate POC

This folder contains a minimal Terraform configuration that deploys an nginx container on AWS ECS Fargate using the default VPC.

## What it creates

- ECS Cluster
- ECS Task Definition (Fargate, 0.25 vCPU / 512 MB, nginx:latest)
- ECS Service (1 task, public IP assigned)
- Security Group (inbound port 80, all outbound)

## Pre-requisites

* Terraform 1.x
* AWS Account

## Quick start

Add to `.bashrc` or `.zshrc`

```bash
export AWS_ACCESS_KEY_ID=(your access key id)
export AWS_SECRET_ACCESS_KEY=(your secret access key)
```

then run

```bash
source .bashrc
# OR
omz reload
```

Check

```bash
printenv | grep AWS
```

Deploy:

```bash
terraform init
terraform apply
```

## Test it

Fargate task public IPs are assigned at runtime to the task's ENI and are not available as native Terraform outputs. Fetch it with the AWS CLI after apply:

```bash
# 1. Get the task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster fargate-poc-cluster \
  --service-name fargate-poc-service \
  --region us-east-2 \
  --query 'taskArns[0]' \
  --output text)

# 2. Get the ENI ID attached to the task
ENI_ID=$(aws ecs describe-tasks \
  --cluster fargate-poc-cluster \
  --tasks $TASK_ARN \
  --region us-east-2 \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text)

# 3. Get the public IP from the ENI
aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI_ID \
  --region us-east-2 \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text | cat
```

Then:

```bash
curl http://<public-ip>
```

You should see the nginx welcome page.

## Clean up

```bash
terraform destroy
```
