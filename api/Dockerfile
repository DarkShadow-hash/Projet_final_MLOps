# A exécuter depuis le dossier racine Projet final MLOps :
# docker build -t mlops-api-helene -f api/Dockerfile .
# Nom mlops-api-helene

# Utilisation d'une image de base Python légère 
FROM python:3.9-slim

WORKDIR /app

# Copier le fichier de dépendances et installer les paquets
# Karel utilisera cette étape pour installer les dépendances de votre API
COPY api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le reste du code de l'API (app.py)
COPY api/app.py .

# Copier le dossier du modèle (Contrat Klara : le modèle sera placé ici)
COPY api/model /app/api/model

# Exposer les deux ports (API par défaut 5000 et Métriques 9090)
# Malika doit ouvrir ces ports dans les Security Groups, et Karel les utilisera
ENV API_PORT=5000
ENV METRICS_PORT=9090
EXPOSE $API_PORT
EXPOSE $METRICS_PORT

# Commande de lancement de l'API avec Gunicorn (serveur de production)
# Ceci lance le serveur Flask (app) via Gunicorn (meilleur que Flask dev server)
CMD exec gunicorn --bind 0.0.0.0:$API_PORT app:app