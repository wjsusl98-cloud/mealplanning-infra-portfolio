terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# 이 스택은 네트워크(VPC·EKS·ECR)를 관리하는 플랫폼 스택과 완전히 별개다 —
# IAM 도 별도 4종(infra/iam/mp-dashboard/*.json)이라 이 스택의 apply 주체는
# 플랫폼 스택의 VPC·EKS·ECR을 만들거나 지울 수 없다(전용 guardrail 정책이 explicit Deny).
#   platform stack = VPC·EKS·IRSA·ECR   state: tfstate/platform.tfstate
#   여기          = 대시보드 EC2       state: tfstate/dashboard.tfstate (별도 버킷)
provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      Project  = "mealplanning"
      ManagedBy = "terraform"
      Stack    = "operations-dashboard"
    }
  }
}

# aws_vpc_security_group_ingress_rule 전용 별칭 provider — default_tags를 끈다.
# 이유: 이 리소스는 태그를 지원해서 위 provider를 쓰면 생성 시 태그가 자동으로 같이 붙는데,
# AWS는 "생성 + 태깅" 복합 호출에서 ec2:CreateTags를
# ec2:CreateAction == AuthorizeSecurityGroupIngress 조건으로 별도 허용해야 한다.
# 이 계정의 배포 역할 정책은 그 액션을 허용 목록에 넣지 않았다 — 즉 태그가 같이 실리면
# 호출 전체가 AccessDenied로 막힌다. Terraform은 리소스 단위로 default_tags를 끄는 옵션이
# 없어서(공급자 단위로만 가능) 별칭 provider로 우회한다.
provider "aws" {
  alias   = "no_default_tags"
  region  = var.region
  profile = var.profile
}
