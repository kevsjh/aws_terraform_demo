variable "region" {
  description = "region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "vpc name"
  type        = string
  default     = "demo"
}

variable "http_allowed_cidr" {
  description = "cidr block for http"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_allowed_cidr" {
  description = "cidr block for ssh"
  type        = string
  default     = "0.0.0.0/0"
}

variable "iam_username" {
  description = "list of ip"
  type        = string
  default     = "demo_tester"
}

variable "nginx_name" {
  description = "nginx_name"
  type        = string
  default     = "John Doe"
}
