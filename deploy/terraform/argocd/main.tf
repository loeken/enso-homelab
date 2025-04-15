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

  triggers = {
    always_run = timestamp()
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

resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  chart      = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  namespace  = "kube-system"
  create_namespace = true

  values = [
    <<EOF
controller:
  resources:
    requests:
      memory: "64Mi"
      cpu: "50m"
    limits:
      memory: "128Mi"
      cpu: "100m"
EOF
  ]

  depends_on = [null_resource.validate_kubeconfig]
}

resource "null_resource" "kubeseal_argocd_repo_secret" {
  depends_on = [helm_release.argocd, helm_release.sealed_secrets]

  provisioner "local-exec" {
    command = <<EOT
      cat <<EOF > argocd-repo-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: repo-argocd
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
data:
  name: $(echo -n "${var.argocd_repo_name}" | base64)
  url: $(echo -n "git@github.com:${var.argocd_repo_name}.git" | base64)
  sshPrivateKey: ${var.argocd_deploy_private_key}
type: Opaque
EOF

      # Validate the YAML file
      echo "Validating the generated YAML file..."
      cat argocd-repo-secret.yaml
      kubectl --kubeconfig=kubeconfig.yaml apply --dry-run=client -f argocd-repo-secret.yaml

      # Use the hardcoded service name for kubeseal
      kubeseal --kubeconfig=kubeconfig.yaml --format yaml --controller-name=sealed-secrets --controller-namespace=kube-system < argocd-repo-secret.yaml > sealed-argocd-repo-secret.yaml

      # Apply the sealed secret
      kubectl --kubeconfig=kubeconfig.yaml apply -f sealed-argocd-repo-secret.yaml
    EOT
  }
}
resource "null_resource" "create_argocd_application" {
  depends_on = [null_resource.kubeseal_argocd_repo_secret]

  provisioner "local-exec" {
    command = <<EOT
      cat <<EOF > app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    path: deploy/argocd
    repoURL: git@github.com:${var.argocd_repo_name}
    targetRevision: HEAD
    helm:
      valueFiles:
      - values.yaml
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

      # Apply the Application resource
      echo "Applying the ArgoCD Application resource..."
      kubectl --kubeconfig=kubeconfig.yaml apply -f app-of-apps.yaml
    EOT
  }
}
resource "null_resource" "close_ssh_tunnel" {
  depends_on = [helm_release.argocd, helm_release.sealed_secrets, null_resource.kubeseal_argocd_repo_secret,null_resource.create_argocd_application]

  provisioner "local-exec" {
    command = <<EOT
      if [ -f ssh_tunnel.pid ]; then
        kill $(cat ssh_tunnel.pid) || true
        rm -f ssh_tunnel.pid
      fi
    EOT
  }
}