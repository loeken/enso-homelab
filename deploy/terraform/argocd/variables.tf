variable "kubeconfig_content" {
  type        = string
  description = "Base64-encoded kubeconfig content."
}

variable "ssh_username" {
  type        = string
  description = "The username to use when connecting to the server via SSH."
}

variable "ssh_private_key" {
  type        = string
  description = "The path to the private key to use when connecting to the server via SSH."
}

variable "ssh_server_address" {
  type        = string
  description = "The address of the server to connect to via SSH."
}

variable "ssh_server_port" {
  type        = string
  default     = "22"
  description = "The port to use when connecting to the server via SSH."
}

variable "internal_ip" {
  type        = string
  description = "The internal IP address of the server."
}

variable "external_ip" {
  type        = string
  description = "External IP address of the server."
}

variable "hostname" {
  type        = string
  description = "Hostname of the server."
}