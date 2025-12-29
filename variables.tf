variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "Name of the existing .pem key pair in AWS"
  type        = string
}

variable "openai_api_key" {
  description = "OpenAI API Key for the Cognitive Brain"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.medium"
}

variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
  sensitive   = true
}

variable "linux_password" {
  description = "Set a password for the default user"

  validation {
    condition     = length(var.linux_password) > 0
    error_message = "Please specify a password for the default user."
  }
}