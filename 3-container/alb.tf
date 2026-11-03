resource "aws_lb" "rearc_quest_ecs_alb" {
  name               = "rearc-quest-ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.security_group.id]
  subnets            = [aws_subnet.subnet.id, aws_subnet.subnet2.id]

  tags = {
    Name = "rearc-quest-ecs-alb"
  }
}

resource "aws_lb_listener" "rearc_quest_ecs_alb_listener" {
  load_balancer_arn = aws_lb.rearc_quest_ecs_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rearc_quest_ecs_tg.arn
  }
}

resource "aws_lb_target_group" "rearc_quest_ecs_tg" {
  name        = "rearc-quest-ecs-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path = "/"
  }
}