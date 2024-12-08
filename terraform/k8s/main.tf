################################################################################
# AWS側のStateファイルから必要な情報を取得
################################################################################

data "terraform_remote_state" "aws" {
  backend = "s3"

  config = {
    profile = var.profile
    region  = var.region
    bucket  = var.bucket
    key     = local.aws_state_key
  }
}

locals {
  aws_state_key = "eks-hybrid-raspberrypi/aws.tfstate"

  cluster_name               = data.terraform_remote_state.aws.outputs.cluster_name
  pod_network_cidr           = data.terraform_remote_state.aws.outputs.pod_network_cidr
  eks_cluster_api_private_ip = data.terraform_remote_state.aws.outputs.eks_cluster_api_private_ip
}

################################################################################
# Helm
################################################################################
// ~/.kube/configの自動生成
// kubeconfig ファイルを自動で作成する: https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/create-kubeconfig.html
resource "null_resource" "kubeconfig" {
  triggers = {
    cluster_name = local.cluster_name
  }
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${local.cluster_name}"
  }
}

resource "helm_release" "calico" {
  name       = "calico"
  chart      = "tigera-operator"
  version    = "3.29.1"
  repository = "https://docs.tigera.io/calico/charts"
  namespace  = "kube-system"

  values = [<<EOT
installation:
  enabled: true
  cni:
    type: Calico
    ipam:
      type: Calico
  calicoNetwork:
    bgp: Disabled
    ipPools:
    - cidr: ${local.pod_network_cidr}
      blockSize: 26
      encapsulation: VXLAN
      natOutgoing: Enabled
      nodeSelector: eks.amazonaws.com/compute-type == "hybrid"
  controlPlaneReplicas: 1
  controlPlaneNodeSelector:
    eks.amazonaws.com/compute-type: hybrid
  calicoNodeDaemonSet:
    spec:
      template:
        spec:
          nodeSelector:
            eks.amazonaws.com/compute-type: hybrid
  csiNodeDriverDaemonSet:
    spec:
      template:
        spec:
          nodeSelector:
            eks.amazonaws.com/compute-type: hybrid
  calicoKubeControllersDeployment:
    spec:
      template:
        spec:
          nodeSelector:
            eks.amazonaws.com/compute-type: hybrid
  typhaDeployment:
    spec:
      template:
        spec:
          nodeSelector:
            eks.amazonaws.com/compute-type: hybrid
kubernetesServiceEndpoint:
  host: "${local.eks_cluster_api_private_ip}"
  port: "443"
  EOT
  ]

  depends_on = [null_resource.kubeconfig]
}
