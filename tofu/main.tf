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
  region = "eu-west-3" 
}

# --- DONNÉES ---
data "aws_vpc" "default" {
  default = true
}

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

# --- SÉCURITÉ ---

# 1. SSH (Port 22)
resource "aws_security_group" "allow_ssh" {
  name_prefix = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = data.aws_vpc.default.id
  
  ingress {
    description = "SSH"
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

# 2. API (Ports 80 et 9090)
resource "aws_security_group" "api_sg" {
  name_prefix = "api_sg"
  description = "Allow API HTTP and Prometheus Metrics"
  vpc_id      = data.aws_vpc.default.id
  
  ingress {
    description = "HTTP API"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "Metrics Prometheus"
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

# 3. Monitoring (Ports 3000 et 9090)
resource "aws_security_group" "monitoring_sg" {
  name_prefix = "monitoring_sg"
  description = "Allow Grafana and Prometheus"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus UI"
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

# --- INSTANCES ---

# 4. Instance API
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
              exec > >(tee /var/log/install_script.log|logger -t user-data -s 2>/dev/console) 2>&1

              echo "1. Installation des outils..."
              apt-get update -y
              apt-get install -y git python3-pip python3-venv

              echo "2. Clonage du repo..."
              cd /home/ubuntu
              rm -rf app_repo
              git clone -b test-integration-totale https://github.com/DarkShadow-hash/Projet_final_MLOps.git app_repo
              chown -R ubuntu:ubuntu /home/ubuntu/app_repo
              
              echo "3. Installation dépendances Python..."
              cd /home/ubuntu/app_repo
              # Installation en root pour que le service fonctionne
              pip3 install -r api/requirements.txt
              pip3 install -r mlflow/requirements.txt
              pip3 install pandas flask gunicorn prometheus-client scikit-learn mlflow

              echo "4. Entraînement du modèle..."
              python3 mlflow/train.py
              python3 mlflow/select_best.py

              echo "5. Lancement API..."
              # Lancement sur le port 80 (nécessite root)
              nohup python3 api/app.py > api_log.txt 2>&1 &
              
              echo "Installation terminée !"
              EOF

  tags = {
    Name = "MLOps-API-Instance"
    Role = "API"
  }
}

# 5. Instance Monitoring (Correction du chemin JSON ici)
resource "aws_instance" "monitoring_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "myKey"
  
  vpc_security_group_ids = [
    aws_security_group.allow_ssh.id,
    aws_security_group.monitoring_sg.id,
  ]

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/install_monitoring.log|logger -t user-data -s 2>/dev/console) 2>&1
              
              echo "1. Installation Docker..."
              apt-get update -y && apt-get install -y docker.io git
              systemctl start docker && systemctl enable docker
              usermod -aG docker ubuntu

              echo "2. Récupération du repo..."
              cd /home/ubuntu
              rm -rf monitoring_repo
              git clone -b test-integration-totale https://github.com/DarkShadow-hash/Projet_final_MLOps.git monitoring_repo

              echo "3. Préparation Grafana..."
              mkdir -p /home/ubuntu/grafana/dashboards
              mkdir -p /home/ubuntu/grafana/provisioning/dashboards

              # On utilise le chemin exact que tu as trouvé avec 'ls'
              cp /home/ubuntu/monitoring_repo/monitoring/graphana/Dashboard/dashboard1.json /home/ubuntu/grafana/dashboards/mlops.json

              # Configuration du provisioning
              cat <<EOT > /home/ubuntu/grafana/provisioning/dashboards/main.yaml
              apiVersion: 1
              providers:
                - name: 'MLOps'
                  orgId: 1
                  folder: ''
                  type: file
                  disableDeletion: false
                  updateIntervalSeconds: 10
                  options:
                    path: /var/lib/grafana/dashboards
              EOT

              echo "4. Config Prometheus..."
              mkdir -p /home/ubuntu/prometheus
              # Injection de l'IP dynamique de l'API
              cat <<EOT > /home/ubuntu/prometheus/prometheus.yml
              global:
                scrape_interval: 15s
              scrape_configs:
                - job_name: 'prometheus'
                  static_configs:
                    - targets: ['localhost:9090']
                - job_name: 'mlops-api'
                  metrics_path: '/metrics'
                  static_configs:
                    - targets: ['${aws_instance.api_instance.private_ip}:9090']
              EOT

              echo "5. Lancement des services..."
              docker run -d -p 9090:9090 \
                -v /home/ubuntu/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
                --name prometheus \
                prom/prometheus
              
              docker run -d -p 3000:3000 \
                -v /home/ubuntu/grafana/provisioning/dashboards:/etc/grafana/provisioning/dashboards \
                -v /home/ubuntu/grafana/dashboards:/var/lib/grafana/dashboards \
                --name grafana \
                grafana/grafana
              
              echo "Monitoring prêt !"
              EOF
  
  tags = {
    Name = "MLOps-Monitoring-Instance"
    Role = "Monitoring"
  }
}