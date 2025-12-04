output "output_details" {
  description = "Deployment Output"
  value       = <<-EOF
    🚨 Deployment Output
    VPC ID: ${aws_vpc.main.id}
    App server private IP: ${module.local_ec2.server_priv_ip}
    -----------------------------------------------------------------
    Bastion public IP: ${module.local_ec2.bastion_ip}
    App server public IP: ${module.local_ec2.server_ip}
    🎉 Infrastructure deployed successfully!
  EOF
}