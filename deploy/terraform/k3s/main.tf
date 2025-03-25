provider "null" {}

resource "null_resource" "bootstrap-k3s" {
  provisioner "local-exec" {
    command = <<EOT
    echo '${var.ssh_private_key}' | base64 -d > /tmp/id_ed25519
    chmod 600 /tmp/id_ed25519

    /usr/local/bin/k3sup install \
      --ip ${var.ssh_server_address} \
      --user ${var.ssh_username} \
      --ssh-key /tmp/id_ed25519 \
      --cluster \
      --k3s-version ${var.kubernetes_version} \
      --k3s-extra-args '--disable=traefik --node-external-ip=${var.external_ip} --advertise-address=${var.ssh_server_address} --node-ip=${var.ssh_server_address}'

    rm -f /tmp/id_ed25519
    EOT
  }
}

# resource "null_resource" "nfs_server" {
#   count = var.storage == "local-path" ? 1 : 0
#   connection {
#     type     = "ssh"
#     host     = var.ssh_server_address
#     user     = "${var.ssh_username}"
#     private_key = file("${var.ssh_private_key}")
#   }
  
#   provisioner "remote-exec" {
#     inline = [
#       "sudo apt update -y",
#       "DEBIAN_FRONTEND=noninteractive sudo apt install -y nfs-kernel-server curl",
#       "sudo mkdir -p /mnt/data",
#       "echo '/mnt/data ${var.ssh_server_address}/32(rw,all_squash,anonuid=1000,anongid=1000)' | sudo tee /etc/exports",
#       "sudo chown -R ${var.ssh_username}:${var.ssh_username} /mnt/data",
#       "sudo systemctl restart nfs-kernel-server",
#       "sudo sysctl fs.inotify.max_user_instances=512"
#     ]
#   }

#   depends_on = [
#     null_resource.upload_ips
#   ]
# }