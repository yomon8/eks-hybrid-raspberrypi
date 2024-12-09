output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}
output "pod_network_cidr" {
  description = "Pod Network CIDR"
  value       = var.pod_network_cidr
}

output "commands" {
  description = "🚩 post commands"
  value       = <<EOT
# Raspberry Piの設定実行
ssh user@${var.home_pi_private_ip} 'sudo bash -s' < ./output/setup.sh

# Tunnel1がアップになるのを確認
aws ec2 describe-vpn-connections \
  --profile ${var.profile} \
  --vpn-connection-ids ${aws_vpn_connection.this.id} \
  --query 'VpnConnections[*].VgwTelemetry[0]'

  EOT

}

# EKSのPrivate IPを取得
data "aws_network_interfaces" "eks" {
  filter {
    name   = "group-id"
    values = [module.eks.cluster_security_group_id]
  }
  depends_on = [module.eks.time_sleep]
}
data "aws_network_interface" "eks" {
  id = data.aws_network_interfaces.eks.ids[0]
}

output "eks_cluster_api_private_ip" {
  description = "EKS cluster API private IP"
  value       = data.aws_network_interface.eks.private_ips[0]
}
