resource "null_resource" "decode_kubeconfig" {
  provisioner "local-exec" {
    command = <<EOT
      echo "${var.kubeconfig_content}" | base64 -d > kubeconfig.yaml
    EOT
  }
}

resource "null_resource" "ssh_tunnel" {
  provisioner "local-exec" {
    command = <<EOT
      ssh -i ${var.ssh_private_key} -N -L 127.0.0.1:6433:${var.internal_ip}:6443 ${var.ssh_username}@${var.ssh_server_address} -p ${var.ssh_server_port} &
      echo $! > ssh_tunnel.pid
    EOT
  }
}

resource "null_resource" "rewrite_kubeconfig" {
  depends_on = [null_resource.decode_kubeconfig, null_resource.ssh_tunnel]

  provisioner "local-exec" {
    command = <<EOT
      sed -i 's|server: https://.*:6443|server: https://127.0.0.1:6433|' kubeconfig.yaml
    EOT
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  namespace  = "argocd"

  values = [
    "${file("argocd-values.yaml")}"
  ]

  # Set KUBECONFIG environment variable
  depends_on = [null_resource.rewrite_kubeconfig]

}
