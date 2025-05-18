terraform {
    required_providers {
        proxmox = {
            source = "bpg/proxmox"
            version = "0.38.1"
        }
    }
}
provider "proxmox" {
    endpoint = "https://localhost:${var.tunnel_port}/api2/json" 
    username = "root@pam"
    password = var.root_password
    insecure = true
    tmp_dir  = "/var/tmp"
} 
