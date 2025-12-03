#!/bin/bash

# Script de destruction de l'infrastructure MLOps
# Objectif : Supprimer les ressources AWS et nettoyer les fichiers générés

# 1. Charger les variables d'environnement (Credentials AWS)
if [ -f .env ]; then
    source .env
else
    echo "  Attention : Fichier .env introuvable."
fi

echo "  DESTRUCTION DE L'INFRASTRUCTURE"
echo "  ATTENTION : Cette action va supprimer définitivement :"
echo "    - Les instances EC2 (API & Monitoring)"
echo "    - Les Security Groups associés"
echo "    - Les données présentes sur ces machines"

# 2. Demande de confirmation (Sécurité pour éviter les accidents)
read -p " Êtes-vous sûr de vouloir tout détruire ? (y/n) " -n 1 -r
echo    # (nouvelle ligne)
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo " Annulation."
    exit 1
fi

# 3. Destruction via OpenTofu
echo "Lancement de la destruction OpenTofu..."
if [ -d "tofu" ]; then
    cd tofu
    # La commande pour détruire l'infra (inverse de apply)
    tofu destroy -auto-approve
    cd ..
else
    echo " Erreur : Dossier 'tofu' introuvable."
    exit 1
fi

# 4. Nettoyage des fichiers locaux générés
echo "🧹 Nettoyage des fichiers locaux..."
if [ -f "ansible/inventory.yml" ]; then
    rm ansible/inventory.yml
    echo "   ansible/inventory.yml supprimé."
else
    echo "   Aucun inventaire à supprimer."
fi

echo " Infrastructure détruite avec succès."