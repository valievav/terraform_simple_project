variable "server_port" {
    description = "The port which the server will use to handle HTTP requests"
    type        = number
    default     = 8080

  validation {
    condition     = var.server_port > 0 && var.server_port < 65536
    error_message = "The server port must be between 1 and 65535."
  }

}
