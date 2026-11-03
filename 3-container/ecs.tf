data "aws_ssm_parameter" "rearc_quest_ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "rearc_quest_ecs_lt" {
  name_prefix   = "ecs-template"
  image_id      = data.aws_ssm_parameter.rearc_quest_ecs_ami.value
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.security_group.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_instance.arn
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ecs-instance"
    }
  }

  user_data = filebase64("${path.module}/ecs.sh")
}

resource "aws_autoscaling_group" "rearc_quest_ecs_asg" {
  vpc_zone_identifier = [aws_subnet.subnet.id, aws_subnet.subnet2.id]
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1

  launch_template {
    id      = aws_launch_template.rearc_quest_ecs_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "rearc-quest-ecs-cluster"
}

resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
  name = "test1"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.rearc_quest_ecs_asg.arn

    managed_scaling {
      maximum_scaling_step_size = 1000
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 3
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "rearc_quest_capacity_provider" {
  cluster_name = aws_ecs_cluster.ecs_cluster.name

  capacity_providers = [aws_ecs_capacity_provider.ecs_capacity_provider.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
  }

  lifecycle {
    # Recreate the cluster association whenever the capacity provider changes or is replaced.
    replace_triggered_by = [aws_ecs_capacity_provider.ecs_capacity_provider]
  }
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family             = "rearc-quest-ecs-task"
  network_mode       = "awsvpc"
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  cpu                = 256

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name = "rearc-quest"
      # The image pushed by docker_registry_image in ecr.tf, pinned by digest so each push
      # creates a new task definition revision rather than relying on the mutable :latest tag.
      image     = "${aws_ecr_repository.my-rearc-quest-ecr-repo.repository_url}@${docker_registry_image.media-handler.sha256_digest}"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          # defined in rearc-quest/src/000.js:4. With awsvpc, hostPort must equal containerPort.
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "SECRET_WORD"
          value = var.secret_word
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "rearc_quest_ecs_service" {
  name            = "rearc-quest-ecs-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count   = 2

  network_configuration {
    subnets         = [aws_subnet.subnet.id, aws_subnet.subnet2.id]
    security_groups = [aws_security_group.security_group.id]
  }

  force_new_deployment = true
  placement_constraints {
    type = "distinctInstance"
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
    weight            = 100
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.rearc_quest_ecs_tg.arn
    container_name   = "rearc-quest"
    container_port   = 3000
  }

  depends_on = [aws_autoscaling_group.rearc_quest_ecs_asg]
}