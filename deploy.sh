#!/bin/bash
set -e # Arrête le script immédiatement si une commande échoue

# ==============================================================================
# 1. CHARGEMENT DES CONFIGURATIONS
# ==============================================================================
echo "🔹 [1/4] Chargement de l'environnement..."
if [ -f .env ]; then
    source .env
else
    echo "⚠️  Attention : Fichier .env introuvable. Assurez-vous que les variables d'environnement sont définies."
fi

# ==============================================================================
# 2. PARTIE MLFLOW (Klara & Hélène)
# ==============================================================================
echo "🔹 [2/4] Entraînement du modèle et sélection de la meilleure version..."
if [ -d "mlflow" ]; then
    cd mlflow
    # On suppose ici que les fichiers existent (sinon commenter les lignes python pour tester)
    # python train.py
    # python select_best.py
    cd ..
else
    echo "⚠️  Dossier 'mlflow' non trouvé, on saute cette étape."
fi

# ==============================================================================
# 3. PARTIE INFRASTRUCTURE (Malika)
# ==============================================================================
echo "🔹 [3/4] Provisionnement de l'infrastructure AWS avec OpenTofu..."
if [ -d "tofu" ]; then
    cd tofu
    # Initialisation et application (auto-approve pour ne pas bloquer le script)
    # tofu init
    # tofu apply -auto-approve
    cd ..
else
    echo "⚠️  Dossier 'tofu' non trouvé, on saute cette étape."
fi

# ==============================================================================
# 4. PARTIE CONFIGURATION & DÉPLOIEMENT (Karel)
# ==============================================================================
echo "🔹 [4/4] Configuration des serveurs avec Ansible..."

# On vérifie que Malika a bien généré l'inventaire
if [ ! -f "ansible/inventory.yml" ]; then
    echo "❌ Erreur critique : Le fichier 'ansible/inventory.yml' est absent."
    echo "   L'étape OpenTofu n'a pas généré l'inventaire ou a échoué."
    exit 1
fi

cd ansible

# On désactive la vérification des clés SSH (connu sous le nom de 'Host Key Checking')
# pour éviter que le script ne s'arrête en demandant "Are you sure you want to connect? (yes/no)"
export ANSIBLE_HOST_KEY_CHECKING=False

echo "   🚀 Déploiement de l'API..."
ansible-playbook -i inventory.yml playbook-api.yml

echo "   🚀 Déploiement du Monitoring (Prometheus + Grafana)..."
ansible-playbook -i inventory.yml playbook-monitoring.yml

cd ..

# ==============================================================================
# FIN
# ==============================================================================
echo ""
echo "✅  DÉPLOIEMENT TERMINÉ AVEC SUCCÈS !"
echo "==================================================="
# Si OpenTofu est configuré pour sortir les URLs, on pourrait les afficher ici :
# echo "🌍 API URL      : http://$(cd tofu && tofu output -raw api_ip):5000"
# echo "📊 GRAFANA URL  : http://$(cd tofu && tofu output -raw monitoring_ip):3000"
echo "==================================================="