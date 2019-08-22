provider "acme" {
  version    = "~> 1.3.5"
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

resource "tls_private_key" "acme_registration_private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "registration" {
  account_key_pem = tls_private_key.acme_registration_private_key.private_key_pem
  email_address   = "alltheclouds@effy.is"
}

resource "acme_certificate" "certificate" {
  account_key_pem           = acme_registration.registration.account_key_pem
  common_name               = "alltheclouds.app"
  subject_alternative_names = ["*.alltheclouds.app"]

  dns_challenge {
    provider = "exec"
    config = {
      "EXEC_PATH" = "echo"
    }
  }
}