output "vpc_a_id" {
  description = "VPC A ID"
  value       = aws_vpc.vpc_a.id
}

output "vpc_b_id" {
  description = "VPC B ID"
  value       = aws_vpc.vpc_b.id
}

output "peering_connection_id" {
  description = "VPC Peering Connection ID (pcx-...)"
  value       = aws_vpc_peering_connection.peering.id
}

output "subnet_a_public_id" {
  description = "Subnet A Public ID"
  value       = aws_subnet.subnet_a_public.id
}

output "subnet_a_private_id" {
  description = "Subnet A Private ID"
  value       = aws_subnet.subnet_a_private.id
}

output "subnet_b_private_id" {
  description = "Subnet B Private ID"
  value       = aws_subnet.subnet_b_private.id
}

output "route_table_a_public_id" {
  description = "Route Table A Public ID"
  value       = aws_route_table.rt_a_public.id
}

output "route_table_a_private_id" {
  description = "Route Table A Private ID"
  value       = aws_route_table.rt_a_private.id
}

output "route_table_b_private_id" {
  description = "Route Table B Private ID"
  value       = aws_route_table.rt_b_private.id
}

output "bastion_instance_id" {
  description = "Bastion Instance ID"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Bastion Public IPv4"
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Bastion Private IPv4"
  value       = aws_instance.bastion.private_ip
}

output "app_a_instance_id" {
  description = "App-A Instance ID"
  value       = aws_instance.app_a.id
}

output "app_a_private_ip" {
  description = "App-A Private IPv4"
  value       = aws_instance.app_a.private_ip
}

output "app_b_instance_id" {
  description = "App-B Instance ID"
  value       = aws_instance.app_b.id
}

output "app_b_private_ip" {
  description = "App-B Private IPv4"
  value       = aws_instance.app_b.private_ip
}

output "ssh_config_snippet" {
  description = "SSH config snippet for ~/.ssh/config"
  value       = <<-EOT
Host ewb-bastion
    HostName ${aws_instance.bastion.public_ip}
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes

Host ewb-app-a
    HostName 10.10.2.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion

Host ewb-app-b
    HostName 10.20.1.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion
  EOT
}
