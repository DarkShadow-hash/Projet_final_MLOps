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

# --- 1. Groupe de Securite SSH (Commun) ---
resource "aws_security_group" "allow_ssh" {
  name_prefix = "allow_ssh"
  description = "Autorise le trafic SSH entrant"
  vpc_id      = data.aws_vpc.default.id
  
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

# --- 2. Groupe de Securite API (Port 80 et 9090) ---
resource "aws_security_group" "api_sg" {
  name_prefix = "api_sg"
  description = "Autorise HTTP (API) et Metrics"
  vpc_id      = data.aws_vpc.default.id
  
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

# --- 3. NOUVEAU : Groupe de Securite Monitoring (Grafana/Prometheus) ---
resource "aws_security_group" "monitoring_sg" {
  name_prefix = "monitoring_sg"
  description = "Autorise Grafana (3000) et Prometheus (9090)"
  vpc_id      = data.aws_vpc.default.id

  # Grafana Dashboard
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Prometheus Interface
  ingress {
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

# --- 4. Instance API (Tout automatisé : Git + Train + Run) ---
resource "aws_instance" "api_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "myKey" 

  vpc_security_group_ids = [
    aws_security_group.allow_ssh.id,
    aws_security_group.api_sg.id,
  ]

  user_data = <<-EOF
              #!/bin/bash
              # Log de l'installation dans /var/log/install_script.log
              exec > >(tee /var/log/install_script.log|logger -t user-data -s 2>/dev/console) 2>&1

              echo "1. Installation des outils système..."
              apt-get update -y
              apt-get install -y git python3-pip python3-venv

              echo "2. Récupération du code (Branche Test)..."
              cd /home/ubuntu
              rm -rf app_repo
              # On clone TA branche spécifique pour avoir les modifs
              git clone -b test-integration-totale https://github.com/DarkShadow-hash/Projet_final_MLOps.git app_repo
              chown -R ubuntu:ubuntu /home/ubuntu/app_repo
              
              echo "3. Installation des librairies Python..."
              cd /home/ubuntu/app_repo
              # Installation globale (en root) pour éviter les soucis de PATH
              pip3 install -r api/requirements.txt
              pip3 install -r mlflow/requirements.txt
            
              echo "4. Entraînement du modèle (Automatisation Klara)..."
              # On génère le modèle sur place
              python3 mlflow/train.py
              python3 mlflow/select_best.py

              echo "5. Lancement de l'API (Automatisation Hélène)..."
              # On lance sur le port 80 (root nécessaire, ça tombe bien user_data EST root)
              nohup python3 api/app.py > api_log.txt 2>&1 &
              
              echo "Installation terminée avec succès !"
              EOF

  tags = {
    Name = "MLOps-API-Instance"
    Role = "API"
  }
}


# --- 5. Instance Monitoring (Docker + Grafana + Prometheus) ---
resource "aws_instance" "monitoring_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "myKey" 
  
  # On attache le SSH + le nouveau groupe Monitoring
  vpc_security_group_ids = [
    aws_security_group.allow_ssh.id,
    aws_security_group.monitoring_sg.id,
  ]

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/install_monitoring.log|logger -t user-data -s 2>/dev/console) 2>&1
              
              echo "1. Installation de Docker..."
              apt-get update -y
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu

              echo "2. Lancement des conteneurs..."
              # Prometheus (Port 9090)
              docker run -d -p 9090:9090 --name prometheus prom/prometheus
              
              # Grafana (Port 3000)
              docker run -d -p 3000:3000 --name grafana grafana/grafana
              
              echo "Monitoring prêt !"
              EOF
  
  tags = {
    Name = "MLOps-Monitoring-Instance"
    Role = "Monitoring"
  }
}