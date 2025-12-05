# MLOps Pipeline – Déploiement Automatisé d’un Modèle ML avec API et Monitoring

## Description du Projet
Ce projet met en place un pipeline complet MLOps couvrant l’entraînement d’un modèle, la création d’une API de prédiction, le provisioning automatisé d’infrastructure cloud et la configuration d’un système de monitoring. L’objectif est d’obtenir un déploiement reproductible, automatisé et observable d’un service de ML.

## Architecture Générale
Le pipeline se compose de quatre phases principales :

1. **Phase A – Machine Learning (MLflow)**
   - Entraînement de plusieurs modèles.
   - Suivi des expérimentations avec MLflow.
   - Sélection et export du meilleur modèle pour l’API.

2. **Phase B – Infrastructure as Code (OpenTofu/Terraform)**
   - Provisionnement automatisé de deux instances EC2 :
     - Instance API (déploiement du conteneur).
     - Instance Monitoring (Prometheus et Grafana).
   - Configuration des Security Groups et génération des outputs nécessaires (adresses IP).

3. **Phase C – Configuration & Déploiement (Ansible)**
   - Installation de Docker sur les deux instances.
   - Déploiement de l’API conteneurisée.
   - Déploiement de Prometheus et Grafana avec configuration du scraping.

4. **Phase D – Monitoring**
   - Visualisation des métriques via Grafana.
   - Vérification de l’exposition des métriques Prometheus depuis l’API.

## Technologies Utilisées
- **MLflow** : gestion des expérimentations et export du modèle.
- **Docker** : conteneurisation de l’API.
- **OpenTofu/Terraform** : création de l’infrastructure AWS.
- **AWS EC2** : hébergement des services.
- **Ansible** : configuration des machines et déploiement des services.
- **Prometheus & Grafana** : monitoring et visualisation.

## Objectif du Projet
Automatiser l'ensemble du cycle de vie du modèle, depuis l'entraînement jusqu’au déploiement et à la supervision, en appliquant les bonnes pratiques DevOps et MLOps : automatisation, reproductibilité, infrastructure as code et observabilité.

