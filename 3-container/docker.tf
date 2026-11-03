resource "docker_image" "rearc_quest_docker_image" {
  name = "rearc-quest:latest"
  build {
    context    = "${path.module}/.."
    dockerfile = "${path.module}/3-container/Dockerfile"
  }
}