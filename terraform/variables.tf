variable "aws_region" {
  description = "AWS Region for deployment"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name tag"
  type        = string
  default     = "EWB-VPC-Peering"
}

variable "student_name" {
  description = "Student name for resource tagging"
  type        = string
  default     = "Prachi"
}

variable "admin_cidr" {
  description = "Your local public IPv4 address CIDR for SSH access to Bastion (e.g. 203.0.113.25/32)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the EC2 key pair (if not generated automatically)"
  type        = string
  default     = "ewb-lab"
}
