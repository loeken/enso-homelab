terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "ime"

    workspaces {
      name = "enso-backend"
    }
  }
}