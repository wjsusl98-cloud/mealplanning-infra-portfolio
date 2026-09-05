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

# EKS 관측 데이터를 조회하고 Bedrock으로 원인 분석을 생성하는 운영 대시보드 EC2용 역할.
# permissions_boundary는 조직 공통 경계 정책 — 이 role이 그 상한을 넘는 권한을 갖지 못하게 한다.
data "aws_iam_policy_document" "dashboard_ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dashboard" {
  name                  = "${var.project_name}-operations-dashboard"
  assume_role_policy    = data.aws_iam_policy_document.dashboard_ec2_trust.json
  permissions_boundary  = var.permissions_boundary_arn
}

resource "aws_iam_instance_profile" "dashboard" {
  name = "${var.project_name}-operations-dashboard"
  role = aws_iam_role.dashboard.name
}

# 원인 분석(RCA) 초안 생성 — 승인된 모델 ARN으로만 범위를 좁힌다.
resource "aws_iam_role_policy" "dashboard_bedrock" {
  name = "bedrock-invoke"
  role = aws_iam_role.dashboard.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
      Resource = var.bedrock_model_arns
    }]
  })
}

# 런타임 비밀(DB 비밀번호 등)은 이 역할 전용 경로만 읽는다 — 다른 서비스 시크릿과 격리.
resource "aws_iam_role_policy" "dashboard_secrets_read" {
  name = "secrets-dashboard-read"
  role = aws_iam_role.dashboard.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/dashboard/*"
    }]
  })
}

data "aws_caller_identity" "current" {}

# 대시보드 앞단(80 = 인증서 발급/갱신)과 EKS→대시보드(8011 = Alertmanager webhook)만 허용.
resource "aws_vpc_security_group_ingress_rule" "dashboard_http" {
  security_group_id = var.dashboard_security_group_id
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol        = "tcp"
  from_port          = 80
  to_port            = 80
  description        = "TLS certificate issuance and renewal"
}

resource "aws_vpc_security_group_ingress_rule" "dashboard_alertmanager_webhook" {
  security_group_id            = var.dashboard_security_group_id
  referenced_security_group_id = var.eks_node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 8011
  to_port                      = 8011
  description                  = "EKS Alertmanager to operations-api webhook"
}

resource "aws_eip" "dashboard" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-eip-dashboard" }
}

resource "aws_instance" "dashboard" {
  ami                    = var.ami_id
  instance_type          = "t3.medium"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.dashboard_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.dashboard.name

  # 컨테이너 경유 호출(Bedrock·DescribeInstances 등)은 IMDS 홉을 하나 더 지난다.
  # hop_limit 1이면 그 호출들이 조용히 실패한다.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 강제
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name      = "${var.project_name}-dashboard"
    Component = "operations-dashboard"
  }
}

resource "aws_eip_association" "dashboard" {
  instance_id   = aws_instance.dashboard.id
  allocation_id = aws_eip.dashboard.id
}
