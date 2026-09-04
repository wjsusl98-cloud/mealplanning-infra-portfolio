terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" { region = var.aws_region }

# EKS 관측 데이터를 조회하는 운영 API가 사용할 최소 권한 역할 예시.
resource "aws_iam_role" "operations_dashboard" {
  name = "${var.project_name}-operations-dashboard"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "bedrock_inference" {
  name = "bedrock-inference"
  role = aws_iam_role.operations_dashboard.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock:InvokeModel"]
      Resource = var.bedrock_model_arns
    }]
  })
}

resource "aws_security_group_rule" "operations_api_from_eks" {
  type                     = "ingress"
  security_group_id        = var.operations_security_group_id
  source_security_group_id = var.eks_node_security_group_id
  protocol                 = "tcp"
  from_port                = 8011
  to_port                  = 8011
}
