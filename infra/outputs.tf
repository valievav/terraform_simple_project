output "public_ip" {
  description = "The public IP address of the server"
  sensitive = false
  value = aws_instance.my_instance.public_ip
}
