variable "ssh_username" {
  type = string
  default = "user"
  description = "The username to use when connecting to the server via SSH."
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
variable "kubernetes_version" {
    type = string
    default = "v1.26.4+k3s1"
    description = "which version of k3s to install, usually 1 versions behind the latest"
}
variable "external_ip" {
    type = string
    default = "1.2.3.4"
    description = "sets the external ip address, a script to update ips and restart k3s is also uploaded to the vm"
}
variable "internal_ip" {
    type = string
    default = "192.168.1.185"
    description = "sets the external ip address, a script to update ips and restart k3s is also uploaded to the vm"
}
variable "ssh_server_address" {
  type = string
  default = "localhost"
  description = "The address of the server to connect to via SSH."
}
variable "storage" {
  type = string
  default = "local-path"
  description = "the default storage class"
}
variable "hostname" {
  type        = string
  description = "Expected hostname of the server"
}