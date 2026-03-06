# Terraform Hello, World with Load Balancer

This folder contains a "Hello, World with Load Balancer" example of a Terraform configuration. 
The configuration deploys a single server in an AWS.

## Pre-requisites

* [Terraform 1.x](https://www.terraform.io/)
* Amazon Web Services (AWS) account

## Quick start

Add to `.bashrc` or `.zshrc` 
```
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

Deploy the code:

```bash
terraform init
terraform apply
```

Wait a few minutes and test it. It may take a long while. 
Take `alb_dns_name` output value. Run `terraform apply` again get `public_ip` if you want to confirm it.
And then:

```bash
curl <alb_dns_name> 
```

You should receive the 'Hello, ...' string in your terminal with the EC2 instance ID.
Repeat the above command a few times and see the intance ID change.
Experiment Terminate any EC2 instance in AWS Console. And check again with the above
command if a third distinct EC2 instance ID is shown. It may also take a long while.


Clean up when you're done:

```bash
terraform destroy
```