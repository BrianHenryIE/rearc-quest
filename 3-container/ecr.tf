# create ecr repo
resource "aws_ecr_repository" "my-rearc-quest-ecr-repo" {
  name = "rearc-quest"
}

# get authorization credentials to push to ecr
data "aws_ecr_authorization_token" "token" {}

# push image to ecr repo
resource "docker_registry_image" "media-handler" {
  name = docker_image.rearc_quest_docker_image.name

  # Re-push whenever the local image is rebuilt; the tag (:latest) alone doesn't change.
  triggers = {
    image_id = docker_image.rearc_quest_docker_image.image_id
  }
}