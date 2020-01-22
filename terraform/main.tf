provider "aws" {
  version = ">= 2.28.1"
  region  = var.region
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.10"
}

data "aws_availability_zones" "available" {
}

locals {
  cluster_name = "dobdata-eks-demo-cluster"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.6.0"

  name                 = "dobdata-vpc-lt"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

module "eks" {
  source           = "terraform-aws-modules/eks/aws"
  cluster_name     = local.cluster_name
  cluster_version  = "1.14"
  subnets          = module.vpc.public_subnets
  vpc_id           = module.vpc.vpc_id
  write_kubeconfig = true
  kubeconfig_name  = "aws-${local.cluster_name}"

  worker_groups = [
    {
      instance_type         = "m4.large"
      asg_min_size          = 2
      asg_max_size          = 5
      autoscaling_enabled   = true
      protect_from_scale_in = true
    }
  ]
}
