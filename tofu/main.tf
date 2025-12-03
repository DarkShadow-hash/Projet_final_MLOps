terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Utilisez une version récente
    }
  }
}

provider "aws" {
  region = "eu-west-3" # Région de Paris, comme dans la démo AWS [cite: 42]

  # L'authentification se fait via les identifiants configurés localement
  # dans le fichier credentials (étape 0.2) [cite: 119, 251]
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- 1. Groupe de Sécurité SSH (pour Ansible) ---
resource "aws_security_group" "allow_ssh" {
  name_prefix = "allow_ssh"
  description = "Autorise le trafic SSH entrant pour Ansible"
  
  # Règle d'entrée (Ingress): Port 22
  ingress {
    description = "Trafic SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Ou une plage d'IP plus restrictive
  }

  # Règle de sortie (Egress): Tout le trafic sortant est autorisé
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 2. Groupe de Sécurité API (Port HTTP/API et Port 9090) ---
resource "aws_security_group" "api_sg" {
  name_prefix = "api_sg"
  description = "Autorise l'accès HTTP et les métriques (9090) à l'instance API"
  
  # Autoriser l'accès HTTP (Port 80) depuis n'importe où
  ingress {
    description = "Trafic HTTP/API"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Autoriser l'accès aux métriques (Port 9090) pour le scraping par Prometheus
  # Ici, on autorise depuis n'importe où pour simplifier, mais en réalité on restreindrait à l'IP de l'Instance Monitoring.
  ingress {
    description = "Métriques Prometheus"
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


# --- 3. Instance API (pour l'API Dockerisée) ---
resource "aws_instance" "api_instance" {
  ami           = data.aws_ami.ubuntu.id
  [cite_start]instance_type = "t3.micro" # Gratuit avec le Free Tier [cite: 380]
  key_name      = "myKey" # Nom de votre clé SSH créée à l'Étape 0.1
  
  # Associer les groupes de sécurité : SSH et API
  vpc_security_group_ids = [
    aws_security_group.allow_ssh.id,
    aws_security_group.api_sg.id,
  ]
  
  tags = {
    Name = "MLOps-API-Instance"
    Role = "API" # Tag utile pour l'inventaire dynamique Ansible
  }
}

# --- 4. Instance Monitoring (pour Prometheus & Grafana) ---
resource "aws_instance" "monitoring_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "myKey"
  
  # Associer le groupe de sécurité SSH
  vpc_security_group_ids = [
    aws_security_group.allow_ssh.id,
  ]
  
  tags = {
    Name = "MLOps-Monitoring-Instance"
    Role = "Monitoring" # Tag utile pour l'inventaire dynamique Ansible
  }
}
