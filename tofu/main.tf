terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Utilisez une version récente
    }
  }
}

provider "aws" {
  region = "eu-west-3" # Région de Paris, comme dans la démo AWS [cite: 42]

  # L'authentification se fait via les identifiants configurés localement
  # dans le fichier credentials (étape 0.2) [cite: 119, 251]
}
