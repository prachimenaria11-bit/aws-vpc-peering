terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project = var.project_name
      Student = var.student_name
    }
  }
}

# -----------------------------------------------------------------------------
# Availability Zone (Keep both VPC subnets in the same AZ for consistency)
# -----------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  target_az = data.aws_availability_zones.available.names[0]
}

# -----------------------------------------------------------------------------
# Amazon Linux 2023 AMI lookup
# -----------------------------------------------------------------------------
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# Key Pair Generation
# -----------------------------------------------------------------------------
resource "tls_private_key" "lab_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ewb_lab" {
  key_name   = var.key_name
  public_key = tls_private_key.lab_key.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.lab_key.private_key_pem
  filename        = "${path.module}/../ssh/ewb-lab.pem"
  file_permission = "0400"
}

# -----------------------------------------------------------------------------
# 01. VPC A & Subnets (10.10.0.0/16)
# -----------------------------------------------------------------------------
resource "aws_vpc" "vpc_a" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ewb-vpc-a"
  }
}

resource "aws_subnet" "subnet_a_public" {
  vpc_id                  = aws_vpc.vpc_a.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = local.target_az
  map_public_ip_on_launch = false

  tags = {
    Name = "ewb-a-public"
  }
}

resource "aws_subnet" "subnet_a_private" {
  vpc_id                  = aws_vpc.vpc_a.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = local.target_az
  map_public_ip_on_launch = false

  tags = {
    Name = "ewb-a-private"
  }
}

resource "aws_internet_gateway" "igw_a" {
  vpc_id = aws_vpc.vpc_a.id

  tags = {
    Name = "ewb-igw-a"
  }
}

# -----------------------------------------------------------------------------
# 02. VPC B & Subnet (10.20.0.0/16)
# -----------------------------------------------------------------------------
resource "aws_vpc" "vpc_b" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ewb-vpc-b"
  }
}

resource "aws_subnet" "subnet_b_private" {
  vpc_id                  = aws_vpc.vpc_b.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = local.target_az
  map_public_ip_on_launch = false

  tags = {
    Name = "ewb-b-private"
  }
}

# -----------------------------------------------------------------------------
# 03. VPC Peering Connection
# -----------------------------------------------------------------------------
resource "aws_vpc_peering_connection" "peering" {
  vpc_id      = aws_vpc.vpc_a.id
  peer_vpc_id = aws_vpc.vpc_b.id
  auto_accept = true

  tags = {
    Name = "ewb-a-b-peer"
  }
}

# -----------------------------------------------------------------------------
# 04. Route Tables & Associations
# -----------------------------------------------------------------------------
# VPC A Public Route Table
resource "aws_route_table" "rt_a_public" {
  vpc_id = aws_vpc.vpc_a.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_a.id
  }

  route {
    cidr_block                = "10.20.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
  }

  tags = {
    Name = "ewb-rt-a-public"
  }
}

resource "aws_route_table_association" "assoc_a_public" {
  subnet_id      = aws_subnet.subnet_a_public.id
  route_table_id = aws_route_table.rt_a_public.id
}

# VPC A Private Route Table
resource "aws_route_table" "rt_a_private" {
  vpc_id = aws_vpc.vpc_a.id

  route {
    cidr_block                = "10.20.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
  }

  tags = {
    Name = "ewb-rt-a-private"
  }
}

resource "aws_route_table_association" "assoc_a_private" {
  subnet_id      = aws_subnet.subnet_a_private.id
  route_table_id = aws_route_table.rt_a_private.id
}

# VPC B Private Route Table
resource "aws_route_table" "rt_b_private" {
  vpc_id = aws_vpc.vpc_b.id

  route {
    cidr_block                = "10.10.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
  }

  tags = {
    Name = "ewb-rt-b-private"
  }
}

resource "aws_route_table_association" "assoc_b_private" {
  subnet_id      = aws_subnet.subnet_b_private.id
  route_table_id = aws_route_table.rt_b_private.id
}

# -----------------------------------------------------------------------------
# 05. Security Groups
# -----------------------------------------------------------------------------
# Bastion Host Security Group (VPC A)
resource "aws_security_group" "sg_bastion" {
  name        = "ewb-sg-bastion"
  description = "Allow inbound SSH from admin IP"
  vpc_id      = aws_vpc.vpc_a.id

  ingress {
    description = "SSH from authorized admin CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ewb-sg-bastion"
  }
}

# App-A Security Group (VPC A)
resource "aws_security_group" "sg_app_a" {
  name        = "ewb-sg-app-a"
  description = "Security group for App-A in VPC A"
  vpc_id      = aws_vpc.vpc_a.id

  ingress {
    description = "SSH inbound from Bastion private IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.1.10/32"]
  }

  ingress {
    description = "ICMP Echo Request from App-B private IP"
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["10.20.1.10/32"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ewb-sg-app-a"
  }
}

# App-B Security Group (VPC B)
resource "aws_security_group" "sg_app_b" {
  name        = "ewb-sg-app-b"
  description = "Security group for App-B in VPC B"
  vpc_id      = aws_vpc.vpc_b.id

  ingress {
    description = "SSH inbound from Bastion private IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.1.10/32"]
  }

  ingress {
    description = "ICMP Echo Request from App-A private IP"
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["10.10.2.10/32"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ewb-sg-app-b"
  }
}

# -----------------------------------------------------------------------------
# 06. EC2 Instances
# -----------------------------------------------------------------------------
# ewb-bastion (VPC A Public Subnet)
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.ewb_lab.key_name
  subnet_id                   = aws_subnet.subnet_a_public.id
  private_ip                  = "10.10.1.10"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg_bastion.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "ewb-bastion"
  }
}

# ewb-app-a (VPC A Private Subnet)
resource "aws_instance" "app_a" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.ewb_lab.key_name
  subnet_id                   = aws_subnet.subnet_a_private.id
  private_ip                  = "10.10.2.10"
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.sg_app_a.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "ewb-app-a"
  }
}

# ewb-app-b (VPC B Private Subnet)
resource "aws_instance" "app_b" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.ewb_lab.key_name
  subnet_id                   = aws_subnet.subnet_b_private.id
  private_ip                  = "10.20.1.10"
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.sg_app_b.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "ewb-app-b"
  }
}
