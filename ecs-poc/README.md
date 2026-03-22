# AWS ECS EC2 Launch Type POC

This folder contains a minimal Terraform configuration that deploys an nginx container on AWS ECS using the **EC2 launch type** with an Auto Scaling Group and Capacity Provider.

## What it creates

- ECS Cluster
- EC2 Auto Scaling Group (1–2 x `t3.micro`, ECS-optimized Amazon Linux 2 AMI)
- ECS Capacity Provider — ties the ASG to the cluster
- IAM Instance Role — grants EC2 instances permission to register with ECS
- Launch Template — bootstraps each EC2 instance into the cluster via `user_data`
- Security Group (inbound on container port, all outbound)
- ECS Task Definition (EC2/bridge network, 256 CPU units / 256 MB, nginx:latest)
- ECS Service (1 desired task, static port mapping)

## Pre-requisites

* Terraform 1.x
* AWS Account

## Quick start

Add to `.bashrc` or `.zshrc`:

```bash
export AWS_ACCESS_KEY_ID=(your access key id)
export AWS_SECRET_ACCESS_KEY=(your secret access key)
```

Then reload:

```bash
source .bashrc
# OR
omz reload
```

Verify:

```bash
printenv | grep AWS
```

Deploy:

```bash
terraform init
terraform apply
```

## Test it

After `apply`, get the public IP of the EC2 container instance:

```bash
# Get the instance ID registered with the cluster
INSTANCE_ID=$(aws ecs list-container-instances \
  --cluster ecs-poc-cluster \
  --region us-east-2 \
  --query 'containerInstanceArns[0]' \
  --output text | xargs -I{} aws ecs describe-container-instances \
  --cluster ecs-poc-cluster \
  --region us-east-2 \
  --container-instances {} \
  --query 'containerInstances[0].ec2InstanceId' \
  --output text)

# Get its public IP
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region us-east-2 \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

curl http://$PUBLIC_IP 
# OR
open http://$PUBLIC_IP # It will open in the browser
```

You should see the nginx welcome page.

## What to check in the AWS Console

**ECS Console** (us-east-2)

- Clusters --> ecs-poc-cluster: Status `ACTIVE`, Infrastructure tab --> 1 container instance registered
- Clusters --> ecs-poc-cluster --> Services --> ecs-poc-service: Running count `1`, Desired `1`, Events tab --> "reached a steady state"
- Clusters --> ecs-poc-cluster --> Tasks: 1 task `RUNNING`, click it --> container `nginx` is `RUNNING` with no exit code

**EC2 Console**

- Auto Scaling Groups --> ecs-poc-asg: Desired `1`, In service `1`
- Instances --> instance tagged `AmazonECSManaged`: State `running`, has a public IP

## Clean up

```bash
terraform destroy
```

> Note: The ECS Capacity Provider may prevent the cluster from being deleted if the ASG still has instances. Run `terraform destroy` and wait for the ASG to scale down completely.
