terraform {
  required_version = ">= v1.10.1"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 2.34.0"
    }
  }
  backend "s3" {
    key = "eks-hybrid-raspberrypi/k8s.tfstate"
  }

}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}


