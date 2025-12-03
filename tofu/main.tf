# tofu/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  # Region de Paris
  region = "eu-west-3" 
}

# Recupere l'ID du VPC par defaut
data "aws_vpc" "default" {
  default = true
}

# Recupere la derniere AMI Ubuntu 22.04 LTS
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] 
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- 1. Groupe de Securite SSH (pour Ansible) ---
resource "aws_security_group" "allow_ssh" {
  name_prefix = "allow_ssh"
  description = "Autorise le trafic SSH entrant pour Ansible"
  vpc_id      = data.aws_vpc.default.id # Ligne ajoutée
  
  ingress {
    description = "Trafic SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 2. Groupe de Securite API (Port HTTP/API et Port 9090) ---
resource "aws_security_group" "api_sg" {
  name_prefix = "api_sg"
  description = "Autorise l acces HTTP et les metriques 9090 a l instance API"
  vpc_id      = data.aws_vpc.default.id # Ligne ajoutée
  
  ingress {
    description = "Trafic HTTP/API"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "Metriques Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# --- 3. Instance API (pour l API Dockerisee) ---
resource "aws_instance" "api_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "myKey" 
  
  vpc_security_group_ids = [
    aws_security_group.allow_ssh.id,
    aws_security_group.api_sg.id,
  ]
  
  tags = {
    Name = "MLOps-API-Instance"
    Role = "API"
  }
}

# --- 4. Instance Monitoring (pour Prometheus & Grafana) ---
resource "aws_instance" "monitoring_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "myKey"
  
  vpc_security_group_ids = [
    aws_security_group.allow_ssh.id,
  ]
  
  tags = {
    Name = "MLOps-Monitoring-Instance"
    Role = "Monitoring"
  }
}