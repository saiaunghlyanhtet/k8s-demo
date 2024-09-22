provider "aws" {
  region = "ap-northeast-1"
}

# Fetch the available availability zones
data "aws_availability_zones" "available" {}

# Create a VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "vpc-for-eks"
  cidr   = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway      = true
  single_nat_gateway      = true
  map_public_ip_on_launch = true

  tags = {
    "Name" = "web-quickstart-vpc"
  }
}

# Create EKS Cluster using the VPC
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "eks-cluster"
  cluster_version = "1.29"
  subnet_ids      = concat(module.vpc.public_subnets, module.vpc.private_subnets)
  vpc_id          = module.vpc.vpc_id

  # Enable OIDC for IAM Roles for Service Accounts (IRSA)
  enable_irsa = true

  # Define managed node groups
  eks_managed_node_groups = {
    eks_nodes = {
      desired_capacity = 3
      max_capacity     = 5
      min_capacity     = 1
      instance_type    = "t2.micro"
    }
  }
}

# AWS Load Balancer Controller Add-on
resource "aws_eks_addon" "aws_load_balancer_controller" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-load-balancer-controller"
  addon_version            = "v2.3.0"
  service_account_role_arn = aws_iam_role.eks_oidc_role.arn
}

# AWS EBS CSI Driver Add-on
resource "aws_eks_addon" "aws_ebs_csi_driver" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.eks_oidc_role.arn
}

# CloudWatch Logs for EKS
resource "aws_cloudwatch_log_group" "eks_logs" {
  name              = "/aws/eks/web-quickstart"
  retention_in_days = 30

  tags = {
    "Name" = "eks-cloudwatch-log-group"
  }
}

# IAM Role for OIDC Trust for AWS Load Balancer Controller
resource "aws_iam_role" "eks_oidc_role" {
  name = "eks-oidc-role"

  assume_role_policy = data.aws_iam_policy_document.oidc_policy.json

  tags = {
    "Name" = "eks-oidc-role"
  }
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "oidc_policy" {
  statement {
    effect = "Allow"

    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${module.eks.cluster_oidc_issuer_url}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.cluster_oidc_issuer_url}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

output "oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

