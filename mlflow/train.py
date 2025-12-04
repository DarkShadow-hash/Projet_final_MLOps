import mlflow
import mlflow.sklearn
from sklearn import datasets
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score


def load_data():
    """Charge le dataset Iris depuis scikit-learn."""
    iris = datasets.load_iris()
    X, y = iris.data, iris.target
    return X, y


def train_and_log_model(params):
    """
    Entraîne un RandomForest avec les paramètres donnés
    et log tout dans un run MLflow.
    """
    X, y = load_data()

    # Split train / test (30% test)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.3, random_state=42
    )

    # Modèle
    model = RandomForestClassifier(
        n_estimators=params["n_estimators"],
        max_depth=params["max_depth"],
        random_state=42,
    )

    # Run MLflow
    with mlflow.start_run():
        mlflow.log_param("n_estimators", params["n_estimators"])
        mlflow.log_param("max_depth", params["max_depth"])

        model.fit(X_train, y_train)
        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)

        mlflow.log_metric("accuracy", accuracy)

        mlflow.sklearn.log_model(
            sk_model=model,
            artifact_path="model",
        )

        print(f"Run terminé - params={params}, accuracy={accuracy:.4f}")


def main():
    mlflow.set_experiment("iris-random-forest")

    param_grid = [
        {"n_estimators": 10, "max_depth": 3},
        {"n_estimators": 10, "max_depth": 5},
        {"n_estimators": 50, "max_depth": 3},
        {"n_estimators": 50, "max_depth": 5},
        {"n_estimators": 100, "max_depth": None},
    ]

    for params in param_grid:
        train_and_log_model(params)


if __name__ == "__main__":
    main()
