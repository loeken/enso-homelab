variable "user_name" {
  type        = string
  default     = "user"
  description = "The username to use when connecting to the server via SSH."

  validation {
    condition     = var.user_name != ""
    error_message = "The user_name must not be an empty string."
  }
}

variable "hostname" {
  type        = string
  default     = "localhost"
  description = "The address of the server to connect to via SSH."

  validation {
    condition     = var.hostname != ""
    error_message = "The hostname must not be an empty string."
  }
}

variable "port" {
  type        = number
  default     = 22
  description = "The port of the server to connect to via SSH."
}

variable "vm_count" {
  type        = number
  default     = 1
  description = "Defines the total amount of VMs to create."
}

variable "vm_core_count" {
  type        = number
  default     = 10
  description = "Defines the total core count that are assigned to the VM."
}

variable "vm_memory_mb" {
  type        = string
  default     = "28672"
  description = "Defines the total MB that are assigned to the VM."

  validation {
    condition     = var.vm_memory_mb != ""
    error_message = "The vm_memory_mb must not be an empty string."
  }
}

variable "vm_disk_size_gb" {
  type        = number
  default     = 50
  description = "Defines the total size for the virtual disk in GB."
}

variable "data_disk_size_gb" {
  type        = number
  default     = 1000
  description = "Defines the total size for the data disk in GB. attached to each vm"
}
variable "root_password" {
  type        = string
  default     = "topsecure"
  description = "This is the root password, not used for ssh - mostly to login to Proxmox's web UI."

  validation {
    condition     = var.root_password != ""
    error_message = "The root_password must not be an empty string."
  }
}

variable "macaddr_first_five" {
  type        = string
  default     = "8E:AB:AB:4C:CE"
  description = "You can use this MAC partial address to achieve static IPs by setting static mappings in your DHCP server."

  validation {
    condition     = var.macaddr_first_five != ""
    error_message = "The macaddr_first_five must not be an empty string."
  }
}

variable "proxmox_node_name" {
  type        = string
  default     = "homeserver"
  description = "The name of the Proxmox node."

  validation {
    condition     = var.proxmox_node_name != ""
    error_message = "The proxmox_node_name must not be an empty string."
  }
}

variable "proxmox_vm_name" {
  type        = string
  default     = "k3s-enso"
  description = "The start of the name of the Proxmox VM."

  validation {
    condition     = var.proxmox_vm_name != ""
    error_message = "The proxmox_vm_name must not be an empty string."
  }
}

variable "ssh_public_key" {
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
  description = "The path to the public key to use when connecting to the server via SSH."

  validation {
    condition     = var.ssh_public_key != ""
    error_message = "The ssh_public_key must not be an empty string."
  }
}

variable "external_ip" {
  type        = string
  default     = "1.2.3.4"
  description = "Sets the external IP address used for provisioning and SSH tunneling."

  validation {
    condition     = var.external_ip != ""
    error_message = "The external_ip must not be an empty string."
  }
}
variable "node_names" {
  description = "The list of Proxmox node names"
  type        = list(string)
  default     = []
}

variable "ssh_server_address" {
  type = string
  default = "localhost"
  description = "The address of the server to connect to via SSH."
}
variable "ssh_private_key" {
  type = string
  default = "~/.ssh/id_ed25519"
  description = "The path to the private key to use when connecting to the server via SSH."
}
variable "ssh_server_port" {
  type = string
  default = "22"
  description = "The port to use when connecting to the server via SSH."
}
variable "ssh_username" {
  type = string
  default = "user"
  description = "The username to use when connecting to the server via SSH."
}