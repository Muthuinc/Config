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
  region = "ap-south-1"
}

#1

resource "aws_ami_from_instance" "My_ami1" {
  name               = "first"                          # AMI name
  source_instance_id = "i-09f7f333d829ffbc2"            # EC2 Instance ID from where we create the AMI
  snapshot_without_reboot = "true"
}

#2

#resource "aws_ami_from_instance" "My_ami2" {
 # name               = "second"                          # AMI name
  #source_instance_id = "i-0127e56699deade55"             # EC2 Instance ID from where we create the AMI
  #snapshot_without_reboot = "true"
#}

# Create AMI for launch template & auto-scaling
# The below AMI will get the values from the variables.tf file
#resource "aws_ami_copy" "My_ami" {
 # name               = "for terraform"                           # AMI name
 # source_ami_id = "ami-0f5ee92e2d63afc18"                             # EC2 Instance ID from where we create the AMI
  #source_ami_region = "ap-south-1"
#}

# ------------------------------------------------------------------------------------------------

#Creating security group for the loadbalancer alowing only port 80

# -------------------------------------------------------------------------------------------------

# Create launch template which is required for auto-scaling
#1
resource "aws_launch_template" "My_template" {
  name = "My_template"
  description = "for auto scaling"
  image_id = aws_ami_from_instance.My_ami1.id                     # This is the AMI which we create before look above
  instance_type = "t2.micro"
  #security_groups     = ["aws_security_group.group1.name"]
  #vpc_security_group_ids = ["sg-0f33201aaee3c26e2"]
  key_name = "Avam"
  
 user_data = base64encode(
  <<-EOF
    #!/bin/bash
    sudo systemctl restart docker
    sudo docker restart $(sudo docker ps -aq)
  EOF
)

  network_interfaces {
    associate_public_ip_address = true
    security_groups = ["sg-0f33201aaee3c26e2"]
  }
}

#2


# -------------------------------------------------------------------------------------------
resource "aws_autoscaling_group" "My_asg" {     # Auto-scaling group for instance 1
  name                      = "Muthu"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = [ "subnet-00090d0e2e4ba9096" , "subnet-0b258bd7a88020687"]  # These subnets should be same as our instance VPC
  launch_template {
    id      = aws_launch_template.My_template.id
    version = "$Latest"
  }
}



resource "aws_lb_target_group" "CustomTG" {
  name     = "Mytargetgp"
  port     = 80                     # this is the port which we access our application in our EC2 instance
  protocol = "HTTP"
  vpc_id   = "vpc-0acc23cf8265dbf18"                                 # VPC where our Ec2 is running
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




resource "aws_lb" "alb" {
  name               = "Mylb"
  internal           = false
  load_balancer_type = "application"
  security_groups     = ["sg-0f33201aaee3c26e2"]       # The security group for the loadbalancer to follow
  subnets            = ["subnet-00090d0e2e4ba9096" , "subnet-0b258bd7a88020687"] # Subnet ID - atleast two subnets must be given - in the same VPC
}

resource "aws_lb_listener" "My-listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"                                   # Our loadbalancer DNS will work under HTTP
  protocol          = "HTTP"
  default_action {
    type             = "forward"                             # Forwarding the request to the target group
    target_group_arn = aws_lb_target_group.CustomTG.arn
  }
}

resource "aws_autoscaling_attachment" "example" {	   # We create two auto-scaling attachment for the two instance - This is instance 1
  autoscaling_group_name = aws_autoscaling_group.My_asg.id   # 1st autoscaling group id
  lb_target_group_arn    = aws_lb_target_group.CustomTG.arn
}

resource "aws_autoscaling_policy" "asg_policy" {
  name                   = "asg"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.My_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "ScaleUpOnHighCPU"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60  # 5 minutes
  statistic           = "Average"
  threshold           = 20
  alarm_description  = "Scale up when CPU utilization is high"
  alarm_actions      = [aws_autoscaling_policy.asg_policy.arn]  # Replace with your policy ARN

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.My_asg.name  # Replace with your ASG name
  }
}
resource "aws_autoscaling_policy" "scale_down_policy1" {
  name                   = "asg-scale-down1"
  scaling_adjustment     = -1  # Scale down by 1 instance
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.My_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_scale_down_alarm" {
  alarm_name          = "ScaleDownOnLowCPU"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60  # 1 minute
  statistic           = "Average"
  threshold           = 20  # Scale down when CPU utilization goes below 20%
  alarm_description  = "Scale down when CPU utilization is low"
  alarm_actions      = [aws_autoscaling_policy.scale_down_policy1.arn]  # Replace with your policy ARN

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.My_asg.name  # Replace with your ASG name
  }
}



