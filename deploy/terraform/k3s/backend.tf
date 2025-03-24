terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "enso-backend"

    workspaces {
      name = "enso-backend"
    }
  }
}