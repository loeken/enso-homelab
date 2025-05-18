resource "null_resource" "ssh_key_gen" {
  connection {
    type        = "ssh"
    host        = var.external_ip
    user        = var.user_name
    private_key = file("~/.ssh/id_ed25519")
    port        = var.port
  }

  provisioner "remote-exec" {
    inline = [
        "mkdir -p /home/${var.user_name}/.ssh",
        "if [ ! -f /home/${var.user_name}/.ssh/id_ed25519 ]; then ssh-keygen -t ed25519 -f /home/${var.user_name}/.ssh/id_ed25519 -N ''; fi"
    ]
  }
  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P ${var.port} ${var.user_name}@${var.external_ip}:/home/${var.user_name}/.ssh/id_ed25519.pub /opt/${replace(var.external_ip, ".", "_")}_id_ed25519.pub"
  }
}

data "local_file" "proxmox_pub_key" {
  filename = "/opt/${replace(var.external_ip, ".", "_")}_id_ed25519.pub"
  depends_on = [null_resource.ssh_key_gen]
}

resource "proxmox_virtual_environment_vm" "k3s_vm" {
  count = var.vm_count

  name      = "${var.proxmox_vm_name}-${format("%02d", count.index+1)}"
  node_name = var.node_names[count.index % length(var.node_names)]
  vm_id     = 100 + count.index # Adjust VM ID as needed


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
    dedicated = "${var.vm_memory_mb}"
  }
  cpu {
    type = "host"
    cores = "${var.vm_core_count}"
    sockets = 1
  }
  # VM configuration as per your requirements
  startup {
    order      = "3"
    up_delay   = "60"
    down_delay = "60"
  }

  disk {
    file_format = "raw"
    datastore_id = "local"
    size = "${var.vm_disk_size_gb}"
    interface = "virtio0"
  }

  initialization {
    datastore_id = "local"
    interface = "ide2"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    dns {
      server = "8.8.8.8 1.1.1.1"
    }
    user_account {
      keys     = [trimspace("${file("~/.ssh/id_ed25519.pub")}"), trimspace("${data.local_file.proxmox_pub_key.content}")]
      username = var.user_name
    }
  }

  network_device {
    mac_address = "${var.macaddr_first_five}:${format("%02x", count.index+1)}"
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }
  serial_device {}
}


resource "null_resource" "update" {
  count = var.vm_count
  depends_on = [proxmox_virtual_environment_vm.k3s_vm]
  
  connection {
    type        = "ssh"
    host        = proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses[1][0]
    user        = var.user_name
    private_key = file("~/.ssh/id_ed25519")

    bastion_host = var.external_ip
    bastion_port = var.port
    bastion_user = var.user_name
    bastion_private_key = file("~/.ssh/id_ed25519")
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt upgrade -y",
    ]
  }
}

resource "null_resource" "k3sup_installation" {
  connection {
    type        = "ssh"
    host        = var.external_ip
    user        = var.user_name
    private_key = file("~/.ssh/id_ed25519")
    port        = var.port
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sLS https://get.k3sup.dev | sh",
      "sudo install k3sup /usr/local/bin/"
    ]
  }
  depends_on = [
    null_resource.update
  ]
}
resource "null_resource" "k3s-installation" {
  count      = 1
  depends_on = [null_resource.update, null_resource.k3sup_installation]

  connection {
    type        = "ssh"
    host        = var.external_ip
    user        = var.user_name
    private_key = file("~/.ssh/id_ed25519")
    port        = var.port
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
        extra_args="--disable=traefik,servicelb --node-external-ip=${var.external_ip} --advertise-address=${proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses[1][0]} --node-ip=${proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses[1][0]} --cluster-init"
        k3sup install --host ${proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses[1][0]} --ssh-key /home/${var.user_name}/.ssh/id_ed25519 --user ${var.user_name} --cluster --k3s-version ${var.kubernetes_version} --k3s-extra-args "$extra_args"

        # Loop to wait for the metrics API to be up
        echo "Waiting for the metrics API to be up..."
        until kubectl get --raw "/apis/metrics.k8s.io/v1beta1" &> /dev/null; do 
          echo "Metrics API not ready yet, waiting..."
          sleep 5
        done
        echo "Metrics API is up and running."
      EOT
    ]
  }

  provisioner "local-exec" {
    command = format("scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P %s %s@%s:/home/%s/kubeconfig ./kubeconfig",
      var.port,
      var.user_name,
      var.external_ip,
      var.user_name
    )
  }
}

resource "null_resource" "k3s-join-master" {
  count = var.vm_count > 1 ? var.vm_count - 1 : 0
  depends_on = [null_resource.k3s-installation]

  connection {
      type        = "ssh"
      host        = var.external_ip
      user        = var.user_name
      private_key = file("~/.ssh/id_ed25519")
      port        = var.port
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
        extra_args="--disable=traefik,servicelb --node-external-ip=${var.external_ip} --advertise-address=${proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses[1][0]} --node-ip=${proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses[1][0]}"
        k3sup join --host ${proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses[1][0]} --ssh-key /home/${var.user_name}/.ssh/id_ed25519 --user ${var.user_name} --server-ip ${proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses[1][0]} --k3s-version ${var.kubernetes_version} --k3s-extra-args "$extra_args"
      EOT
    ]
  }
}
resource "null_resource" "k3s-join-worker" {
  count = var.vm_count > 3 ? var.vm_count - 1 : 0
  depends_on = [null_resource.k3s-join-master]

  connection {
      type        = "ssh"
      host        = var.external_ip
      user        = var.user_name
      private_key = file("~/.ssh/id_ed25519")
      port        = var.port
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
        extra_args="--disable=traefik,servicelb --node-external-ip=${var.external_ip} --advertise-address=${proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses[1][0]} --node-ip=${proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses}"
        k3sup join --host ${proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses[1][0]} --ssh-key /home/${var.user_name}/.ssh/id_ed25519 --user ${var.user_name} --server-ip ${proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses[1][0]} --k3s-version ${var.kubernetes_version} --k3s-extra-args "$extra_args"
      EOT
    ]
  }
}

resource "null_resource" "upload_ips" {
    count = var.vm_count
    depends_on = [null_resource.k3s-join-master]
    connection {
        type     = "ssh"
        host     = proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses[1][0]
        user     = var.user_name
        private_key = file("~/.ssh/id_ed25519")
        bastion_host = var.external_ip
        bastion_port = var.port
        bastion_user = var.user_name
        bastion_private_key = file("~/.ssh/id_ed25519")
    }
    provisioner "file" {
        source     = "update_ips.sh"
        destination = "/tmp/update_ips.sh"
    }
    provisioner "remote-exec" {
        inline = [
            "chmod +x /tmp/update_ips.sh",
            "sudo mv /tmp/update_ips.sh /usr/local/bin/",
        ]
    }
}
resource "null_resource" "create_cronjob" {
  count = var.vm_count
  depends_on = [null_resource.upload_ips]
  
  connection {
    type        = "ssh"
    host        = proxmox_virtual_environment_vm.k3s_vm[count.index].ipv4_addresses[1][0]
    user        = var.user_name
    private_key = file("~/.ssh/id_ed25519")
    bastion_host = var.external_ip
    bastion_port = var.port
    bastion_user = var.user_name
    bastion_private_key = file("~/.ssh/id_ed25519")
  }

  provisioner "remote-exec" {
    inline = [
      "echo '* * * * * root /usr/local/bin/update_ips.sh' | sudo tee /etc/cron.d/update_ips_cron",
      "sudo chmod 0644 /etc/cron.d/update_ips_cron",
      "sudo systemctl restart cron",
    ]
  }
}