
# Define a local variable to remove "https://" from the ecr_proxy_endpoint
locals {
  clean_image_repo_url = replace(data.aws_ecr_authorization_token.token.proxy_endpoint, "https://", "")
}

resource "docker_image" "rearc_quest_docker_image" {
  name = "${local.clean_image_repo_url}/rearc-quest:latest"
  build {
    context    = "${path.module}/.."
    dockerfile = "${path.module}/3-container/Dockerfile"
    # The quest's bin/* are x86-64 Linux binaries, and the ECS task runs X86_64.
    # Without this, building on Apple Silicon produces a linux/arm64 image.
    platform = "linux/amd64"
  }
}