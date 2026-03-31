variable "container_port" {
  description = "Port the Flask container listens on"
  type        = number
  default     = 5000
}

variable "instance_type" {
  description = "EC2 instance type for ECS container hosts"
  type        = string
  default     = "t3.micro"
}
