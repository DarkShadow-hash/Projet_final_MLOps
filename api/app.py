import os
import time
import json
import logging
import pandas as pd
from flask import Flask, request, jsonify
import mlflow
from prometheus_client import start_http_server, Counter, Histogram, generate_latest

# Configuration et logging :
# L'API utilisera par défaut le port 5000 et les métriques seront sur 9090 pour que Karel 
# puisse avoir accès aux métriques.
API_PORT = int(os.environ.get("API_PORT", 5000))
METRICS_PORT = 9090

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Chargement du Modèle :
MODEL_PATH = "api/model/model_mlflow" 
model = None 

try:
    model = mlflow.pyfunc.load_model(MODEL_PATH) 
    logger.info("Modèle MLflow chargé avec succès.")
except Exception as e:
    logger.error(f"Erreur lors du chargement du modèle: {e}")

# Instrumentation Prometheus :
# 1). Compteur pour le nombre total de requêtes.
REQUEST_COUNT = Counter(
    'http_requests_total', 
    'Nombre total de requêtes HTTP par méthode et statut.', 
    ['method', 'endpoint', 'status_code']
)

# 2). Histogramme pour suivre la latence des prédictions.
PREDICTION_LATENCY_SECONDS = Histogram(
    'prediction_latency_seconds', 
    'Latence des requêtes de prédiction.',
    # Argument buckets : Paliers pour mesurer la distribution en secondes
    # Mesure de 10 millisecondes (0.01s) à 5 secondes (5.0s) et au-delà (float('inf'))
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, float('inf')) 
)

def log_request(method, endpoint, status_code):
    REQUEST_COUNT.labels(method, endpoint, status_code).inc()

# Endpoints de l'API :

@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint pour le healthcheck de l'API."""
    status = 'OK' if model is not None else 'MODEL_UNAVAILABLE'
    status_code = 200 if model is not None else 503
    log_request('GET', '/health', status_code)
    
    return jsonify({"status": status, "model_loaded": model is not None}), status_code
#http://localhost:5000/health

@app.route('/predict', methods=['POST'])
@PREDICTION_LATENCY_SECONDS.time() 
def predict():
    """Endpoint POST pour retourner une prédiction."""
    data = request.get_json(force=True)
    status_code = 200
    
    if model is None:
        log_request('POST', '/predict', 503)
        return jsonify({"error": "Modèle non chargé, service indisponible."}), 503
    
    try:
        input_df = pd.DataFrame([data])
        predictions = model.predict(input_df)
        result = {'prediction': predictions.tolist()}
        
    except Exception as e:
        logger.error(f"Erreur lors de la prédiction: {e}")
        result = {"error": f"Erreur de traitement des données: {e}"}
        status_code = 400
        
    log_request('POST', '/predict', status_code)
    return jsonify(result), status_code

@app.route('/metrics', methods=['GET'])
def metrics():
    """Endpoint pour exposer les métriques Prometheus."""
    log_request('GET', '/metrics', 200)
    return generate_latest(), 200
#http://localhost:9090/metrics

# Lancement du serveur :

if __name__ == '__main__':
    # Démarrage du serveur Prometheus en parallèle (port 9090) 
    start_http_server(METRICS_PORT)
    logger.info(f"Serveur Prometheus démarré sur le port {METRICS_PORT}")

    # Démarrage du serveur Flask (l'API)
    logger.info(f"Serveur Flask démarré sur le port {API_PORT}")
    app.run(host='0.0.0.0', port=API_PORT)