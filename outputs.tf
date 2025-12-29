output "honeypot_public_ip" {
  description = "The public IP address of the Honeypot"
  value       = aws_instance.labyrinth_node.public_ip
}

output "ssh_command_honeypot" {
  description = "Command to enter the Honeypot (Port 22)"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.labyrinth_node.public_ip}"
}

output "ssh_command_management" {
  description = "Command to manage the real server (Port 22222)"
  value       = "ssh -i ${var.key_name}.pem -p 22222 ubuntu@${aws_instance.labyrinth_node.public_ip}"
}