variable "region" {
  description = "AWS 리전. state 버킷·플랫폼 스택과 같아야 한다."
  type        = string
  default     = "ap-northeast-2"
}

variable "profile" {
  description = <<-EOT
    apply에 쓰는 ~/.aws 프로필. 기본값을 두지 않는다 — 전용 IAM 그룹이 붙은
    개인 프로필이어야 하고, 잘못된 프로필로 절반쯤 apply되는 것보다
    처음부터 멈추는 쪽이 싸다.
  EOT
  type        = string
}

# ── 플랫폼 스택 리소스를 이름으로 조회하기 위한 키 ──────────────────────
# ID를 박아두지 않는 이유: 재생성 때 조용히 어긋난다(드리프트를 apply 시점에
# 바로 드러내려면 이름 조회가 낫다).

variable "service_vpc_name" {
  description = "플랫폼 스택이 만든 서비스 VPC의 Name 태그."
  type        = string
  default     = "mp-vpc-service"
}

variable "dashboard_subnet_name" {
  description = <<-EOT
    대시보드 EC2를 둘 공개 서브넷의 Name 태그. 배포 역할의 ec2:RunInstances
    허용이 이 서브넷 ARN 하나로 고정돼 있다 — 다른 서브넷으로 바꾸면
    apply가 AccessDenied로 막힌다(IAM 정책도 같이 갱신해야 한다).
  EOT
  type        = string
  default     = "mp-subnet-public-ap-northeast-2a"
}

variable "dashboard_sg_name" {
  description = <<-EOT
    플랫폼 스택이 미리 만들어 둔 보안 그룹 — 443 인바운드 + 전체 아웃바운드만
    있고, 이 스택이 80·8011 인바운드 2줄을 여기 추가한다. SG 자체는 여기서
    재생성하지 않는다.
  EOT
  type        = string
  default     = "mp-sg-dashboard"
}

variable "node_sg_name" {
  description = "EKS 노드 보안 그룹. Alertmanager webhook(8011) 인바운드의 출발지로 참조한다."
  type        = string
  default     = "mp-sg-eks-node"
}

# ── 인스턴스 런타임 권한 ──────────────────────────────────────────────

variable "bedrock_model_arns" {
  description = <<-EOT
    Operations RCA/RAG가 호출하는 Bedrock 모델 ARN 목록(교차리전 추론
    프로파일 + 기반 모델 + RAG 임베딩용 모델).

    교차리전 추론 프로파일의 foundation-model ARN이 리전 하나만 있으면
    안 된다 — 요청이 프로파일이 실제로 라우팅하는 다른 리전으로 갈 때마다
    그 리전의 foundation-model ARN이 없으면 조용히 AccessDenied가 난다
    (호출부 코드는 라우팅 리전을 선택하지 않는다 — Bedrock이 분산시킨다).
    아래 목록은 프로파일 정의가 실제로 라우팅하는 전체 리전 기준이다 —
    프로파일 정의가 바뀌면 같이 갱신해야 한다.
  EOT
  type        = list(string)
  default = [
    "arn:aws:bedrock:ap-northeast-2:*:inference-profile/apac.amazon.nova-micro-v1:0",
    "arn:aws:bedrock:ap-northeast-2::foundation-model/amazon.nova-micro-v1:0",
    "arn:aws:bedrock:ap-southeast-2::foundation-model/amazon.nova-micro-v1:0",
    "arn:aws:bedrock:ap-northeast-1::foundation-model/amazon.nova-micro-v1:0",
    "arn:aws:bedrock:ap-south-1::foundation-model/amazon.nova-micro-v1:0",
    "arn:aws:bedrock:ap-southeast-1::foundation-model/amazon.nova-micro-v1:0",
    "arn:aws:bedrock:ap-northeast-3::foundation-model/amazon.nova-micro-v1:0",
    "arn:aws:bedrock:ap-northeast-2::foundation-model/amazon.titan-embed-text-v2:0",
  ]
}

variable "finops_dashboard_resource_read_policy_arn" {
  description = <<-EOT
    비용 조회용 리소스 읽기 정책(EC2/EBS/EKS/ElastiCache/ELB Describe 등)의
    ARN. 이 스택에 정의가 없다 — 다른 곳에서 관리 중으로 추정된다. 빈
    문자열이면 attachment를 만들지 않는다(ARN 확정 전까지 apply를 막지
    않기 위함). 이 ARN이 담을 수 있는 action은 이 role의 permissions
    boundary가 허용하는 범위(Describe/List 계열)를 넘지 못한다.
  EOT
  type        = string
  default     = ""
}
