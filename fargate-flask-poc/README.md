# AWS Fargate Flask POC

This folder contains a minimal Terraform configuration that deploys a simple Flask server on AWS ECS Fargate, using a custom Docker image hosted in ECR.

## What it creates

- ECR Repository (to host the Flask Docker image)
- ECS Cluster
- ECS Task Definition (Fargate, 0.25 vCPU / 512 MB, Flask on port 5000)
- ECS Service (1 task, public IP assigned)
- Security Group (inbound port 5000, all outbound)

## Pre-requisites

* Terraform 1.x
* Docker
* AWS CLI
* Amazon Web Services (AWS) account

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

### 1. Deploy infrastructure

```bash
terraform init
terraform apply
```

### 2. Build and push the Flask image to ECR

```bash
./build_and_push.sh
```

> **Note: `pass not initialized` error (Linux / Docker Desktop)**
>
> On Linux, Docker Desktop manages `~/.docker/config.json` and enforces `credsStore: pass`.
> Editing the file has no effect because Docker Desktop restores it on each command.
>
> `build_and_push.sh` handles this automatically by:
> 1. Capturing the active Docker socket from the current context before overriding `DOCKER_CONFIG`
> 2. Writing ECR credentials directly into a temporary config directory (bypassing `docker login` and the credential store entirely)
> 3. Cleaning up the temp directory on exit

### 3. Restart the service to pick up the new image

```bash
aws ecs update-service \
  --cluster fargate-flask-poc-cluster \
  --service fargate-flask-poc-service \
  --force-new-deployment \
  --region us-east-2
```

## Test it

Fargate task public IPs are assigned at runtime to the task's ENI and are not available as native Terraform outputs. Fetch it with the AWS CLI after apply:

```bash
# 1. Get the task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster fargate-flask-poc-cluster \
  --service-name fargate-flask-poc-service \
  --region us-east-2 \
  --query 'taskArns[0]' \
  --output text)

# 2. Get the ENI ID attached to the task
ENI_ID=$(aws ecs describe-tasks \
  --cluster fargate-flask-poc-cluster \
  --tasks $TASK_ARN \
  --region us-east-2 \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text)

# 3. Get the public IP from the ENI
FLASK_SERVICE=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI_ID \
  --region us-east-2 \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text)
```

Then:

```bash
curl http://$FLASK_SERVICE:5000
```

You should see: `Hello from Flask on Fargate!`

## Clean up

```bash
terraform destroy
```
