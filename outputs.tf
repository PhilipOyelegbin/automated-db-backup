output "output_details" {
  description = "Deployment Output"
  value       = <<-EOF
    🚨 Deployment Output
    VPC ID: ${aws_vpc.main.id}
    App server1 private IP: ${module.local_ec2.server_priv_ip[0]}
    App server2 private IP: ${module.local_ec2.server_priv_ip[1]}
    -----------------------------------------------------------------
    Bastion public IP: ${module.local_ec2.bastion_ip}
    App server1 public IP: ${module.local_ec2.server_ip[0][0]}
    App server2 public IP: ${module.local_ec2.server_ip[0][1]}
    🎉 Infrastructure deployed successfully!
  EOF
}