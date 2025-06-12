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

    if [ "${var.is_primary}" = "true" ]; then
      echo "🟢 Installing K3s primary node..."
      /usr/local/bin/k3sup install \
        --ip ${var.ssh_server_address} \
        --user ${var.ssh_username} \
        --ssh-key /tmp/id_ed25519 \
        --ssh-port ${var.ssh_server_port} \
        --cluster \
        --k3s-version ${var.kubernetes_version} \
        --k3s-extra-args "--disable=traefik --node-external-ip=${var.external_ip} --advertise-address=${var.internal_ip} --node-ip=${var.internal_ip}"
    else
      echo "🔵 Joining K3s cluster via ${var.k3s_primary_internal_ip}..."
      /usr/local/bin/k3sup join \
        --ip ${var.ssh_server_address} \
        --user ${var.ssh_username} \
        --ssh-key /tmp/id_ed25519 \
        --ssh-port ${var.ssh_server_port} \
        --server-ip ${var.k3s_primary_internal_ip} \
        --k3s-version ${var.kubernetes_version} \
        --k3s-extra-args "--node-external-ip=${var.external_ip} --node-ip=${var.internal_ip}"
    fi

    rm -f /tmp/id_ed25519
    EOT
  }

  depends_on = [ null_resource.check_hostname ]
}
resource "null_resource" "upload_ips" {
  depends_on = [null_resource.bootstrap-k3s]

  provisioner "local-exec" {
    command = <<EOT
    echo '${var.ssh_private_key}' | base64 -d > /tmp/id_ed25519
    chmod 600 /tmp/id_ed25519

    scp -P ${var.ssh_server_port} -i /tmp/id_ed25519 -o StrictHostKeyChecking=no update_ips.sh ${var.ssh_username}@${var.ssh_server_address}:/tmp/update_ips.sh
    ssh -p ${var.ssh_server_port} -i /tmp/id_ed25519 -o StrictHostKeyChecking=no ${var.ssh_username}@${var.ssh_server_address} "chmod +x /tmp/update_ips.sh && sudo mv /tmp/update_ips.sh /usr/local/bin/"

    rm -f /tmp/id_ed25519
    EOT
  }
}

resource "null_resource" "create_cronjob" {
  depends_on = [null_resource.upload_ips]

  provisioner "local-exec" {
    command = <<EOT
    echo '${var.ssh_private_key}' | base64 -d > /tmp/id_ed25519
    chmod 600 /tmp/id_ed25519

    ssh -p ${var.ssh_server_port} -i /tmp/id_ed25519 -o StrictHostKeyChecking=no ${var.ssh_username}@${var.ssh_server_address} "\
      echo '* * * * * root /usr/local/bin/update_ips.sh' | sudo tee /etc/cron.d/update_ips_cron && \
      sudo chmod 0644 /etc/cron.d/update_ips_cron && \
      sudo systemctl restart cron"

    rm -f /tmp/id_ed25519
    EOT
  }
}