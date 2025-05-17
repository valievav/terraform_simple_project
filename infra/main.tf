provider "aws" {
  region = "eu-west-2" # London
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# template for EC2 to be used by autoscaling group
resource "aws_launch_template" "my_template_ec2" {
  name_prefix   = "my-template-"
  image_id      = "ami-0a94c8e4ca2674d5a"
  instance_type = "t2.micro"

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "Hello, World!" > index.html
    nohup busybox httpd -f -p ${var.server_port} &
  EOF
  )

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.my_security_group.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "my-ec2-instance"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# security group for EC2 instances to open 8080 access
resource "aws_security_group" "my_security_group" {
  name = "web"  # name in aws console

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # allow all IPs
  }
}

# autoscaling group for EC2 in case of high load or failure
resource "aws_autoscaling_group" "my_asg" {
  launch_template {
  id      = aws_launch_template.my_template_ec2.id
  version = "$Latest"
}
  vpc_zone_identifier = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"  # check if the instance is healthy based on the load balancer

  min_size = 2
  max_size = 4

  tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }
}

# load balancer to distribute traffic between EC2 instances
resource "aws_lb" "my_load_balancer" {
  name = "web-lb"
  load_balancer_type = "application"
  subnets = data.aws_subnets.default.ids
  security_groups = [aws_security_group.alb_security_group.id]
}

# load balancer listener to listen on port 80 for incoming requests
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.my_load_balancer.arn
  port             = 80
  protocol         = "HTTP"

  # by default it shows a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: Not Found"
      status_code  = 404
    }
  }
}

# application load balancer security group to allow access on port 80
resource "aws_security_group" "alb_security_group" {
  name = "web-alb"

  # allow inboud HTTP requests
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # allow all IPs
  }

  # allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # all protocols
    cidr_blocks = ["0.0.0.0/0"]  # allow all IPs
  }
}

# load balancer to know what EC2 to work with + health check
resource "aws_lb_target_group" "asg" {
  name = "web-asg"
  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id

  # will stop routing traffic to unhealthy instances (detected based on rules below)
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# load balancer listener rule to route traffic to the target group based on rule (for example, 'api' calls to api group)
resource "aws_lb_listener_rule" "asg_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}
