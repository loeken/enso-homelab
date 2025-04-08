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
      echo "${var.ssh_private_key}" | base64 -d > /tmp/id_ed25519
      chmod 600 /tmp/id_ed25519
      nohup ssh -o StrictHostKeyChecking=no -i /tmp/id_ed25519 -N -L 127.0.0.1:6443:${var.internal_ip}:6443 ${var.ssh_username}@${var.ssh_server_address} -p ${var.ssh_server_port} > /dev/null 2>&1 &
      echo $! > ssh_tunnel.pid
    EOT
  }
}

resource "null_resource" "rewrite_kubeconfig" {
  depends_on = [null_resource.decode_kubeconfig, null_resource.ssh_tunnel]

  provisioner "local-exec" {
    command = <<EOT
      sed -i 's|server: https://.*:6443|server: https://127.0.0.1:6443|' kubeconfig.yaml
    EOT
  }
}

resource "null_resource" "validate_kubeconfig" {
  depends_on = [null_resource.rewrite_kubeconfig]

  provisioner "local-exec" {
    command = <<EOT
      echo "Contents of kubeconfig.yaml:"
      cat kubeconfig.yaml

      echo "Testing kubectl connection:"
      i=1
      while [ $i -le 30 ]; do
        if kubectl --kubeconfig=kubeconfig.yaml cluster-info > /dev/null 2>&1; then
          echo "✅ Cluster is ready!"
          exit 0
        else
          echo "Cluster not ready yet. Retrying in 10 seconds... (Attempt $i/30)"
          sleep 10
          i=$((i + 1))
        fi
      done

      echo "❌ Cluster did not become ready in time."
      exit 1
    EOT
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  namespace  = "argocd"
  create_namespace = true

  values = [
    "${file("argocd-values.yaml")}"
  ]

  depends_on = [null_resource.validate_kubeconfig]
}
