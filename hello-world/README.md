# Terraform Hello, World

This folder contains a "Hello, World" example of a Terraform configuration. The configuration 
deploys a single server in an AWS.

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

Clean up when you're done:

```bash
terraform destroy
```