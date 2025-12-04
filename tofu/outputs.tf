# tofu/outputs.tf

output "api_public_ip" {
  description = "IP publique de l'instance API pour les tests et l'inventaire Ansible"
  value       = aws_instance.api_instance.public_ip
}

output "monitoring_public_ip" {
  description = "IP publique de l'instance Monitoring pour Grafana"
  value       = aws_instance.monitoring_instance.public_ip
}

output "grafana_url" {
  description = "URL d'acces a Grafana (Port 3000 par defaut)"
  value       = "http://${aws_instance.monitoring_instance.public_ip}:3000"
}

output "api_test_url" {
  description = "URL de test pour l endpoint /health de l API"
  value       = "http://${aws_instance.api_instance.public_ip}/health"
}