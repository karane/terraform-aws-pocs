variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 80
}

variable "instance_type" {
  description = "EC2 instance type for ECS container hosts"
  type        = string
  default     = "t3.micro"
}
