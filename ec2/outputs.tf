output "bastion_ip" {
  description = "Bastion server public IP"
  value = aws_instance.bastion-server.public_ip
}

output "server_ip" {
  description = "App server public IP"
  value = aws_instance.app-servers.public_ip
}

output "server_priv_ip" {
  description = "App server private IP"
  value = aws_instance.app-servers.private_ip
}
