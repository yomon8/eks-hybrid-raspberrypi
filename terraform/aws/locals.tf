locals {
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  name            = "eks-hybrid-raspberrypi"
  cluster_version = "1.31"

  script_outputs_path = "../../output/setup.sh"
}
