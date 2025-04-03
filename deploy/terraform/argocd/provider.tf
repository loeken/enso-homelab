provider "helm" {
  kubernetes {
    config_path = "${path.module}/kubeconfig.yaml"
  }
}