
resource "tls_private_key" "basic_private_key_pem" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# outputs `cert_pem`.
resource "tls_self_signed_cert" "rearc_quest_cert" {
  private_key_pem = tls_private_key.basic_private_key_pem.private_key_pem

  subject {
    # Hopefully we're allowed to create one for a (sub)domain we don't own.
    common_name  = aws_lb.rearc_quest_ecs_alb.dns_name
    organization = "ACME"
  }

  validity_period_hours = 1200

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Uploads the cert to AWS IAM, so it can be used by the ALB.
resource "aws_iam_server_certificate" "rearc_quest_cert" {
  name             = "rearc_quest_cert"
  certificate_body = tls_self_signed_cert.rearc_quest_cert.cert_pem
  private_key      = tls_private_key.basic_private_key_pem.private_key_pem
}