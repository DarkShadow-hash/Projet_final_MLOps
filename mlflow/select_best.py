import os
import shutil
from pathlib import Path
import mlflow

EXPERIMENT_NAME = "iris-random-forest"
API_MODEL_DIR = Path(__file__).resolve().parent.parent / "api" / "model"


def get_best_run():
    experiment = mlflow.get_experiment_by_name(EXPERIMENT_NAME)
    if experiment is None:
        raise ValueError(f"Expérience '{EXPERIMENT_NAME}' introuvable.")

    runs = mlflow.search_runs(
        experiment_ids=[experiment.experiment_id],
        order_by=["metrics.accuracy DESC"],
        max_results=1,
    )

    if runs.empty:
        raise ValueError("Aucun run trouvé.")

    best_run = runs.iloc[0]
    return best_run


def export_best_model():
    best_run = get_best_run()
    best_run_id = best_run["run_id"]
    best_acc = best_run["metrics.accuracy"]

    print(f"Meilleur run : {best_run_id} (accuracy={best_acc})")

    if API_MODEL_DIR.exists():
        shutil.rmtree(API_MODEL_DIR)
    API_MODEL_DIR.mkdir(parents=True, exist_ok=True)

    mlflow.artifacts.download_artifacts(
        run_id=best_run_id,
        artifact_path="model",
        dst_path=str(API_MODEL_DIR),
    )

    print(f"Modèle exporté dans : {API_MODEL_DIR}")


if __name__ == "__main__":
    export_best_model()
