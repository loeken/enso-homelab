resource "proxmox_virtual_environment_vm" "k3s_vm" {
  count = var.vm_count

  name      = "${var.proxmox_vm_name}-${format("%02d", count.index+1)}"
  node_name = var.node_names[count.index % length(var.node_names)]
  vm_id     = 100 + count.index

  agent {
    enabled = true
  }

  clone {
    vm_id = 999
  }

  lifecycle {
    ignore_changes = [
      network_device,
    ]
  }

  memory {
    dedicated = var.vm_memory_mb
  }

  cpu {
    type    = "host"
    cores   = var.vm_core_count
    sockets = 1
  }

  startup {
    order      = "3"
    up_delay   = "60"
    down_delay = "60"
  }

  dynamic "disk" {
    for_each = var.vm_count > 1 ? [1] : []
    content {
      file_format  = "raw"
      datastore_id = "local"
      size         = var.vm_disk_size_gb
      interface    = "virtio0"
    }
  }

  # For vm_count == 1, no disk block (disk will be added via post-setup)

  initialization {
    datastore_id = "local"
    interface    = "ide2"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    dns {
      server = "8.8.8.8 1.1.1.1"
    }
    user_account {
      keys     = [trimspace(file("~/.ssh/id_ed25519.pub"))]
      username = var.user_name
    }
  }

  network_device {
    mac_address = "${var.macaddr_first_five}:${format("%02x", count.index+1)}"
    bridge      = "vmbr0"
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  # Only autostart for multi-node mode
  started = var.vm_count > 1 ? true : false
}

resource "null_resource" "vm_post_setup" {
  count = var.vm_count == 1 ? 1 : 0

  depends_on = [proxmox_virtual_environment_vm.k3s_vm]

  provisioner "local-exec" {
    command = <<EOT
echo '${var.ssh_private_key}' | base64 -d > /tmp/id_ed25519_vm${count.index}
chmod 600 /tmp/id_ed25519_vm${count.index}

echo "🔐 Testing SSH connectivity..."
if ! ssh -i /tmp/id_ed25519_vm${count.index} -p ${var.ssh_server_port} -o StrictHostKeyChecking=no ${var.ssh_username}@${var.ssh_server_address} 'hostname'; then
  echo "❌ SSH connection failed."
  exit 1
fi

echo "⚙️  Setting vcpus and attaching /dev/sda to VM ID ${100 + count.index}..."
ssh -i /tmp/id_ed25519_vm${count.index} -p ${var.ssh_server_port} -o StrictHostKeyChecking=no ${var.ssh_username}@${var.ssh_server_address} \
  "sudo qm set ${100 + count.index} --vcpus ${var.vm_core_count} && \
   sudo qm set ${100 + count.index} --virtio1 /dev/sda && \
   sudo qm start ${100 + count.index}"

echo "✅ VM ${100 + count.index} updated and started successfully."
EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

# resource "null_resource" "upload_ips" {
#   count       = var.vm_count
#   depends_on  = [proxmox_virtual_environment_vm.k3s_vm]

#   connection {
#     type        = "ssh"
#     host        = proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses[1][0]
#     user        = var.user_name
#     private_key = file("~/.ssh/id_ed25519")
#   }

#   provisioner "file" {
#     source      = "update_ips.sh"
#     destination = "/tmp/update_ips.sh"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "chmod +x /tmp/update_ips.sh",
#       "sudo mv /tmp/update_ips.sh /usr/local/bin/",
#     ]
#   }
# }

# resource "null_resource" "create_cronjob" {
#   count       = var.vm_count
#   depends_on  = [null_resource.upload_ips]

#   connection {
#     type        = "ssh"
#     host        = proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses[1][0]
#     user        = var.user_name
#     private_key = file("~/.ssh/id_ed25519")
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "echo '* * * * * root /usr/local/bin/update_ips.sh' | sudo tee /etc/cron.d/update_ips_cron",
#       "sudo chmod 0644 /etc/cron.d/update_ips_cron",
#       "sudo systemctl restart cron",
#     ]
#   }
# }
