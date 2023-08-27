terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# It takes the AWS cred from the Jenkins. 
# look at the top portion of jenkins file

provider "aws" {
  region = var.region
}

# Create AMI for launch template & auto-scaling
resource "aws_ami_from_instance" "My_ami" {
  name               = var.template_name
  source_instance_id = var.instance_id
  snapshot_without_reboot = "true"
}

resource "aws_security_group" "group2" {
  name        = "allow_port5000"
  description = "Allow all inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description      = "TLS from VPC"
    from_port        = var.security_group_port
    to_port          = var.security_group_port
    protocol         = "tcp"
    cidr_blocks      = var.access_ip
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  tags = {
    Name = "allowall"
  }
}

# Create launch template which is required for auto-scaling
resource "aws_launch_template" "My_template" {
  name = "My_template"
  description = "for auto scaling"
  image_id = aws_ami_from_instance.My_ami.id
  instance_type = "t2.micro"
  #security_groups     = ["aws_security_group.group1.name"]
  #vpc_security_group_ids = ["sg-09afc32cea89cb106"]
  key_name = "Ava"
  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.group2.id]
  }
}

resource "aws_lb_target_group" "CustomTG" {
  name     = "Mytargetgp"
  port     = var.security_group_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "instance"
  health_check {
    path        = "/"
    protocol    = "HTTP"
    interval    = 30
    timeout     = 5
    healthy_threshold = 3
    unhealthy_threshold = 2
    matcher     = "200"
  }
}

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.CustomTG.arn
  target_id        = var.instance_id
  port             = 5000
}

resource "aws_lb" "alb" {
  name               = "Mylb"
  internal           = false
  load_balancer_type = "application"
  security_groups     = [aws_security_group.group1.id]
  subnets            = var.subnet_ids
}
resource "aws_lb_listener" "My-listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.CustomTG.arn
  }
}


