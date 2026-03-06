# Terraform One Web Server

This folder contains a "One Web Server" example of a Terraform configuration. The configuration 
deploys a single web server with security group in an AWS.

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

Wait a few minutes and test it.
Take `public_ip` output value. Run `terraform apply` again get `public_ip` if you want to confirm it.
And then:

```bash
curl <public_ip>:8080 
```

You should receive the 'Hello, ...' string in your terminal.

Clean up when you're done:

```bash
terraform destroy
```