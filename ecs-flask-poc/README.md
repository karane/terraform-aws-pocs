# AWS ECS EC2 Launch Type -- Flask App POC

This folder deploys a custom Python Flask container on AWS ECS using the **EC2 launch type**. The Docker image is built locally and pushed to ECR via `build.sh`. 

## What it creates

- ECR repository -- stores the Flask container image
- CloudWatch Log Group -- streams container stdout/stderr (`/ecs/ecs-flask-poc`, 7-day retention)
- ECS Cluster
- EC2 Auto Scaling Group (1–2 x `t3.micro`, ECS-optimized Amazon Linux 2 AMI)
- ECS Capacity Provider -- ties the ASG to the cluster
- IAM Instance Role -- grants EC2 instances permission to register with ECS and pull from ECR
- IAM Task Execution Role -- grants ECS agent permission to write logs to CloudWatch
- Launch Template -- bootstraps each EC2 instance into the cluster via `user_data`
- Security Group (inbound on port 5000, all outbound)
- ECS Task Definition (EC2/bridge network, 256 CPU units / 256 MB, Flask app from ECR)
- ECS Service (1 desired task, static port mapping)

## Flask app endpoints

- `GET /` -- `{"message": "Hello from ECS Flask POC!"}`
- `GET /health` -- `{"status": "healthy"}`

## Pre-requisites

* Terraform 1.x
* AWS CLI (configured with credentials)
* Docker (running locally)

## Deploy

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

### Step 1 -- Create the ECR repository

```bash
terraform init
terraform apply -target=aws_ecr_repository.flask
```

### Step 2 -- Build and push the Docker image

```bash
./build.sh
```

### Step 3 -- Deploy all remaining infrastructure

```bash
terraform apply
```

## Test it

After `apply`, get the public IP of the EC2 container instance:

```bash
# Get the instance ID registered with the cluster
INSTANCE_ID=$(aws ecs list-container-instances \
  --cluster ecs-flask-poc-cluster \
  --region us-east-2 \
  --query 'containerInstanceArns[0]' \
  --output text | xargs -I{} aws ecs describe-container-instances \
  --cluster ecs-flask-poc-cluster \
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

# Hit the Flask app
curl http://$PUBLIC_IP:5000
curl http://$PUBLIC_IP:5000/health
```

## Rebuild the image after code changes

```bash
./build.sh

# Force ECS to pull the new image
aws ecs update-service \
  --cluster ecs-flask-poc-cluster \
  --service ecs-flask-poc-service \
  --force-new-deployment \
  --region us-east-2
```

## View logs

```bash
aws logs tail /ecs/ecs-flask-poc --follow --region us-east-2
```

## What to check in the AWS Console

**ECR Console** (us-east-2)

- Repositories --> `ecs-flask-poc`: image with tag `latest` present

**ECS Console** (us-east-2)

- Clusters --> `ecs-flask-poc-cluster`: Status `ACTIVE`, Infrastructure tab --> 1 container instance registered
- Clusters --> `ecs-flask-poc-cluster` --> Services --> `ecs-flask-poc-service`: Running count `1`, Events tab --> "reached a steady state"
- Clusters --> `ecs-flask-poc-cluster` --> Tasks: 1 task `RUNNING`, container `flask-app` is `RUNNING`

**CloudWatch Console** (us-east-2)

- Log groups --> `/ecs/ecs-flask-poc`: log streams with Flask startup output

**EC2 Console**

- Auto Scaling Groups --> `ecs-flask-poc-asg`: Desired `1`, In service `1`
- Instances --> instance tagged `AmazonECSManaged`: State `running`, has a public IP

## Clean up

```bash
terraform destroy
```

> Note: The ECS Capacity Provider may prevent the cluster from being deleted if the ASG still has instances. Run `terraform destroy` and wait for the ASG to scale down completely.
