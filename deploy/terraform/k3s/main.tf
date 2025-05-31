provider "null" {}

resource "null_resource" "check_hostname" {
  provisioner "local-exec" {
    command = <<EOT
    echo '${var.ssh_private_key}' | base64 -d > /tmp/id_ed25519
    chmod 600 /tmp/id_ed25519

    EXPECTED_HOSTNAME="${var.hostname}"

    ACTUAL_HOSTNAME=$(ssh -i /tmp/id_ed25519 -p ${var.ssh_server_port} -o StrictHostKeyChecking=no ${var.ssh_username}@${var.ssh_server_address} 'hostname')

    echo "Expected hostname: $EXPECTED_HOSTNAME"
    echo "Actual hostname:   $ACTUAL_HOSTNAME"

    if [ "$ACTUAL_HOSTNAME" != "$EXPECTED_HOSTNAME" ]; then
      echo "❌ Hostname does not match!"
      exit 1
    else
      echo "✅ Hostname verified."
    fi

    rm -f /tmp/id_ed25519
    EOT
  }
}

resource "null_resource" "bootstrap-k3s" {
  provisioner "local-exec" {
    command = <<EOT
    echo '${var.ssh_private_key}' | base64 -d > /tmp/id_ed25519
    chmod 600 /tmp/id_ed25519

    # echo "[DEBUG] Running k3sup install with:"
    # echo "/usr/local/bin/k3sup install \\"
    # echo "  --ip ${var.ssh_server_address} \\"
    # echo "  --user ${var.ssh_username} \\"
    # echo "  --ssh-key /tmp/id_ed25519 \\"
    # echo "  --ssh-port ${var.ssh_server_port} \\"
    # echo "  --cluster \\"
    # echo "  --k3s-version ${var.kubernetes_version} \\"
    # echo "  --k3s-extra-args '--disable=traefik --node-external-ip=${var.external_ip} --advertise-address=${var.internal_ip} --node-ip=${var.internal_ip}'"

    /usr/local/bin/k3sup install \
      --ip ${var.ssh_server_address} \
      --user ${var.ssh_username} \
      --ssh-key /tmp/id_ed25519 \
      --ssh-port ${var.ssh_server_port} \
      --cluster \
      --k3s-version ${var.kubernetes_version} \
      --k3s-extra-args "--disable=traefik --node-external-ip=${var.external_ip} --advertise-address=${var.internal_ip} --node-ip=${var.internal_ip}"

    rm -f /tmp/id_ed25519
    EOT
  }
  depends_on = [ null_resource.check_hostname ]
}


