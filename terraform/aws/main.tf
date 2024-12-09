
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  # Exclude local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

################################################################################
# VPC
################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "= 5.16.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}



################################################################################
# Raspberry Pi VPN 設定
################################################################################

resource "aws_customer_gateway" "this" {
  ip_address = var.home_global_ip
  bgp_asn    = "65000"
  type       = "ipsec.1"
  tags = {
    Name = local.name
  }
}

resource "aws_vpn_gateway" "this" {
  vpc_id = module.vpc.vpc_id
  tags = {
    Name = local.name
  }
}

resource "aws_vpn_gateway_attachment" "this" {
  vpc_id         = module.vpc.vpc_id
  vpn_gateway_id = aws_vpn_gateway.this.id
}

resource "aws_vpn_connection" "this" {
  customer_gateway_id = aws_customer_gateway.this.id
  vpn_gateway_id      = aws_vpn_gateway.this.id
  type                = "ipsec.1"

  static_routes_only = true

  tags = {
    Name = local.name
  }
}

resource "aws_vpn_connection_route" "this" {
  vpn_connection_id      = aws_vpn_connection.this.id
  destination_cidr_block = var.home_network_cidr
}

resource "aws_route" "vpn_gateway_private" {
  count = length(module.vpc.private_route_table_ids)

  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = var.home_network_cidr
  gateway_id             = aws_vpn_gateway.this.id
}

resource "aws_route" "vpn_gateway_public" {
  count = length(module.vpc.public_route_table_ids)

  route_table_id         = module.vpc.public_route_table_ids[count.index]
  destination_cidr_block = var.home_network_cidr
  gateway_id             = aws_vpn_gateway.this.id
}


################################################################################
# EKS
################################################################################
module "eks_hybrid_node_role" {
  source  = "terraform-aws-modules/eks/aws//modules/hybrid-node-role"
  version = "~> 20.31"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = local.name
  cluster_version = local.cluster_version


  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  cluster_security_group_additional_rules = {
    hybrid-all = {
      cidr_blocks = [var.home_network_cidr]
      description = "Allow all traffic from remote node/pod network"
      from_port   = 0
      to_port     = 0
      protocol    = "all"
      type        = "ingress"
    }
  }

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  access_entries = {
    hybrid-node-role = {
      principal_arn = module.eks_hybrid_node_role.arn
      type          = "HYBRID_LINUX"
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_remote_network_config = {
    remote_node_networks = {
      cidrs = [var.node_network_cidr]
    }
    remote_pod_networks = {
      cidrs = [var.pod_network_cidr]
    }
  }
}

################################################################################
# Managed Node
################################################################################

# Hybrid Nodes アクティベーション用
resource "aws_ssm_activation" "this" {
  description        = "EKS Hybrid Nodes Activation"
  iam_role           = module.eks_hybrid_node_role.name
  registration_limit = 10
  tags = {
    EKSClusterARN = "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${module.eks.cluster_name}"
  }
}

################################################################################
# Raspberry Pi Setup Script 出力
################################################################################
resource "local_file" "setup_script" {
  filename = local.script_outputs_path
  content  = <<EOT
#!/bin/bash
set -eu

#############################
# VPN設定
#############################
dpkg --configure -a
apt-get update
apt-get install -y libreswan

cat <<EOF > /etc/ipsec.d/aws.conf
conn aws
    type=tunnel
    authby=secret
    auto=start
    leftid=${var.home_global_ip}
    left=${var.home_pi_private_ip}
    leftsubnet=${var.home_network_cidr}
    right=${aws_vpn_connection.this.tunnel1_address}
    rightsubnet=${module.vpc.vpc_cidr_block}
EOF

cat <<EOF > /etc/ipsec.d/aws.secrets
${var.home_global_ip} ${aws_vpn_connection.this.tunnel1_address} : PSK "${aws_vpn_connection.this.tunnel1_preshared_key}"
EOF

mkdir -p /etc/systemd/system/ipsec.service.d/
cat <<EOF > /etc/systemd/system/ipsec.service.d/ipsec.service
[Unit]
After=network-online.target
Wants=network-online.target
EOF
systemctl daemon-reload
systemctl restart ipsec
systemctl enable ipsec

#############################
# AppArmor無効化
# ※ 今回は本題で無いので無効化していますが本来は必要な部分のみ許可してください
#############################
systemctl disable apparmor
systemctl stop apparmor

#############################
# nodeadmのインストール・初期化
#############################
snap install aws-cli --classic
snap install amazon-ssm-agent --classic
curl -OL 'https://hybrid-assets.eks.amazonaws.com/releases/latest/bin/linux/arm64/nodeadm'
mv nodeadm /usr/bin/nodeadm
chmod +x /usr/bin/nodeadm

cat <<EOF > /root/nodeConfig.yaml
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name:   ${module.eks.cluster_name}
    region: ${data.aws_region.current.name}
  hybrid:
    ssm:
      activationCode: ${aws_ssm_activation.this.activation_code}
      activationId:   ${aws_ssm_activation.this.id}
EOF

nodeadm install ${local.cluster_version} --credential-provider ssm
nodeadm init -c file:///root/nodeConfig.yaml 
nodeadm debug -c file:///root/nodeConfig.yaml


echo "✅ Completed Successfully"
  EOT
}
