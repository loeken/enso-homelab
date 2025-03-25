terraform {
  cloud {
    hostname     = "app.terraform.io"
    organization = "ime"

    workspaces {
      name = "enso-backend"
    }
  }
}
