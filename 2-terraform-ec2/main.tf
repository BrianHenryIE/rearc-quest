# Latest Amazon Linux 2023 AMI. Must be x86_64: the quest's bin/* are x86-64 Linux binaries.
# https://docs.aws.amazon.com/linux/al2023/ug/ec2.html
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# https://us-west-1.console.aws.amazon.com/ec2/home?region=us-west-1#Instances:instanceState=running
resource "aws_instance" "rearc-quest" {
  ami           = data.aws_ssm_parameter.al2023.value
  instance_type = "t3.micro" # Free!
  vpc_security_group_ids = [
    aws_security_group.sg_ssh.id,
    aws_security_group.sg_http.id
  ]

  user_data                   = file("${path.module}/install.sh")
  user_data_replace_on_change = true

  tags = {
    Name = "Rearc_Quest"
  }

  lifecycle {
    # Don't replace the instance every time AWS publishes a new AL2023 AMI.
    ignore_changes = [ami]
  }
}

resource "aws_security_group" "sg_ssh" {
  ingress {
    cidr_blocks = ["13.52.6.112/29"] # us-west-1 range to use EC2 Instance Connect.
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }
}

resource "aws_security_group" "sg_http" {
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 3000 # defined in rearc-quest/src/000.js:4.
    to_port     = 3000
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }
}