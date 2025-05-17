provider "aws" {
  region = "eu-west-2" # London
}

resource "aws_instance" "my_instance" {
  ami = "ami-0a94c8e4ca2674d5a"
  instance_type = "t2.micro"  # free tier

  vpc_security_group_ids = [aws_security_group.my_security_group.id]

  user_data = <<-EOF
    #!/bin/bash
    echo "Hello, World!" > index.html
    nohup busybox httpd -f -p ${var.server_port} &
    EOF

  user_data_replace_on_change = true  # apply user_data on every change

  tags = {
    Name = "my_example-instance_ubuntu"  # name in aws console
  }
}

resource "aws_security_group" "my_security_group" {
  name = "web"  # name in aws console

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # allow all IPs
  }
}
