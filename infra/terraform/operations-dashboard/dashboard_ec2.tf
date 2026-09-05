# 대시보드 EC2 — Operations AI + FinOps 공용.
#
# 이 파일은 예전에 플랫폼 스택 안에 있었다 — IAM 구조(별도 boundary·dev·ops·guardrails
# 정책 4종)가 이미 별도 apply 주체·별도 state 버킷으로 분리돼 있는 게 확인돼 이 스택으로
# 옮겼다. VPC·서브넷·SG는 플랫폼 스택 소유라 여기서는 data 조회만 한다(data.tf) — 이
# 스택이 실수로 그 리소스를 만들거나 지울 수 없다(SG·서브넷 변경은 guardrail 정책의
# explicit Deny로 막혀 있다).

# ── SG 인바운드 2줄 — SG 자체는 플랫폼 스택이 만든다 ──────────────────
# description은 ASCII만 허용된다 — 한글은 terraform plan에서는 안 잡히고 apply의 API
# 호출 시점에 실패한다. 한글 설명은 주석으로 옮긴다.
# 없으면: 80 없음 → Let's Encrypt HTTP-01 발급·갱신 실패 / 8011 없음 → Alertmanager
# webhook이 조용히 안 옴(Operations의 입력 경로 자체).
#
# provider = aws.no_default_tags 필수 — provider.tf 주석 참고. 기본 provider를 쓰면
# default_tags가 자동으로 실려서 AuthorizeSecurityGroupIngress 호출 자체가 막힌다.
resource "aws_vpc_security_group_ingress_rule" "dashboard_http" {
  provider          = aws.no_default_tags
  security_group_id = data.aws_security_group.dashboard.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  description       = "Lets Encrypt HTTP-01 issuance and renewal"
}

resource "aws_vpc_security_group_ingress_rule" "dashboard_alertmanager_webhook" {
  provider                      = aws.no_default_tags
  security_group_id             = data.aws_security_group.dashboard.id
  referenced_security_group_id  = data.aws_security_group.eks_node.id
  ip_protocol                   = "tcp"
  from_port                     = 8011
  to_port                       = 8011
  description                   = "EKS Alertmanager to operations-api webhook"
}

# ── IAM Role / Instance Profile ────────────────────────────────────────

# EC2 1대에는 Instance Profile이 1개만 붙는다 — Operations(Bedrock)와 FinOps(비용 조회)
# 권한을 분리할 수 없다. FinOps 컨테이너가 뚫리면 Bedrock 권한도 같이 넘어간다는 대가를
# 감수한다.
#
# permissions_boundary 필수 — 조직 IAM 정책이 iam:CreateRole을 "PermissionsBoundary가
# 지정 boundary와 같을 때만" 허용한다. 이 인자를 빼면 apply가 그 자리에서 AccessDenied로
# 죽는다.
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
  name                 = "mp-dashboard-ec2"
  assume_role_policy   = data.aws_iam_policy_document.dashboard_ec2_trust.json
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/mp-dashboard-boundary"
}

resource "aws_iam_instance_profile" "dashboard" {
  name = "mp-dashboard-ec2"
  role = aws_iam_role.dashboard.name
}

# Bedrock 권한 — permissions boundary의 RuntimeCommon이 InvokeModel을 이미 허용하므로
# 이 role 정책과의 교집합으로 실제 사용 가능해진다(경계는 상한일 뿐 그 자체로는 권한을
# 주지 않는다).
resource "aws_iam_role_policy" "dashboard_bedrock" {
  name = "bedrock-invoke-nova"
  role = aws_iam_role.dashboard.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "BedrockInvokeNova"
      Effect   = "Allow"
      Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
      Resource = var.bedrock_model_arns
    }]
  })
}

# RCA/챗봇 응답의 Contextual Grounding Check용 Guardrail 관리 권한.
#
# bedrock:CreateGuardrail은 리소스 단위 권한을 지원하지 않는 액션이라, Resource를
# 좁히는 순간 문장이 아예 매칭되지 않고 implicit deny로 떨어진다(실측 확인). 그래서
# 범위 제한은 Resource가 아니라 태그 조건이 한다 — 생성 시 태그를 실제로 달아야
# 통과하는 AWS 표준 tag-on-create 패턴이다.
#
# 반대로 기존 리소스를 ARN으로 가리키는 호출(Update/Get/Delete/CreateGuardrailVersion)은
# 태그를 실어 보내지 않으므로 aws:RequestTag 조건이 성립하지 않는다 — 그쪽은
# aws:ResourceTag(리소스에 이미 붙은 태그) 조건으로 ABAC를 건다.
resource "aws_iam_role_policy" "dashboard_bedrock_guardrail" {
  name = "mp-operations-bedrock-guardrail"
  role = aws_iam_role.dashboard.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GuardrailCreate"
        Effect = "Allow"
        # bedrock:TagResource 필요 — create-guardrail --tags가 내부적으로 별도
        # TagResource 호출을 하는데, 이게 없으면 AccessDeniedException(TagResource on
        # guardrail/*)으로 CreateGuardrail 자체가 실패한다(실측). 사전 정책 시뮬레이션으로는
        # 안 잡힌다 — API 내부에서 발생하는 2차 호출이라 그렇다.
        Action   = ["bedrock:CreateGuardrail", "bedrock:TagResource"]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestTag/Name" = "mp-operations-*"
          }
        }
      },
      {
        Sid    = "GuardrailManageExisting"
        Effect = "Allow"
        Action = [
          "bedrock:CreateGuardrailVersion",
          "bedrock:UpdateGuardrail",
          "bedrock:GetGuardrail",
          "bedrock:DeleteGuardrail",
        ]
        Resource = "arn:aws:bedrock:${var.region}:${data.aws_caller_identity.current.account_id}:guardrail/*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Name" = "mp-operations-*"
          }
        }
      },
      {
        Sid      = "GuardrailList"
        Effect   = "Allow"
        Action   = "bedrock:ListGuardrails"
        Resource = "*"
      },
      {
        Sid      = "GuardrailApply"
        Effect   = "Allow"
        Action   = "bedrock:ApplyGuardrail"
        Resource = "arn:aws:bedrock:${var.region}:${data.aws_caller_identity.current.account_id}:guardrail/*"
      },
    ]
  })
}

# EC2 시작/배포 시 EKS 노드 Private IP를 조회해 프록시 업스트림을 자동 갱신하는 데 필요.
resource "aws_iam_role_policy" "dashboard_describe_instances" {
  name = "describe-mng-nodes"
  role = aws_iam_role.dashboard.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DescribeMngNodes"
      Effect   = "Allow"
      Action   = ["ec2:DescribeInstances"]
      Resource = "*"
    }]
  })
}

# 수동 정책 대신 AWS 관리형 정책을 쓴다 — SSM Agent 핵심 권한(Session Manager 포함)을
# 이 정책 하나가 커버한다.
resource "aws_iam_role_policy_attachment" "dashboard_ssm" {
  role       = aws_iam_role.dashboard.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ── 애플리케이션 런타임 권한 ────────────────────────────────────────────
# ECR은 의도적으로 뺐다 — EC2에서 소스를 직접 빌드해 docker compose로 띄운다
# (레지스트리 이원화를 피하려는 결정). permissions boundary는 ECR pull을 상한으로는
# 허용해 두었지만, 이 role 자체의 정책에 ECR action을 안 넣으면 교집합상 실제로는
# 막힌다 — boundary를 건드리지 않고도 "ECR을 안 쓴다" 결정이 안전하게 지켜진다.

# Secrets Manager mp/prod/dashboard/* — PostgreSQL 비밀번호·CA 등.
resource "aws_iam_role_policy" "dashboard_secrets_read" {
  name = "secrets-dashboard-read"
  role = aws_iam_role.dashboard.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "SecretsDashboardRead"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:mp/prod/dashboard/*"
    }]
  })
}

# SSM Parameter Store /mp/dashboard/* — Kubecost NodePort, 캐시 TTL 등 일반 설정.
resource "aws_iam_role_policy" "dashboard_ssm_params_read" {
  name = "ssm-params-dashboard-read"
  role = aws_iam_role.dashboard.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "SsmParamsDashboardRead"
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
      Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/mp/dashboard/*"
    }]
  })
}

# FinOps 빠른 비용 조회 — Cost Explorer·CloudWatch. Athena·Glue는 의도적으로 없다:
# permissions boundary가 그 액션들을 아예 포함하지 않아서, 이 role에 아무리 허용을
# 붙여도 경계와의 교집합이 없어 실질 권한이 안 생긴다(explicit Deny가 아니라 "경계가
# 허용 안 함"으로 조용히 막히는 형태라 더 위험 — 배포 뒤에야 AccessDenied로 드러난다).
resource "aws_iam_role_policy" "dashboard_finops_cost_read" {
  name = "finops-cost-read"
  role = aws_iam_role.dashboard.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "FinOpsCostRead"
      Effect = "Allow"
      Action = [
        "ce:GetCostAndUsage",
        "ce:GetCostForecast",
        "ce:GetDimensionValues",
        "ce:GetTags",
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics",
      ]
      Resource = "*"
    }]
  })
}

# 기존 리소스 읽기 정책(EC2/EBS/EKS/ElastiCache Describe 등)을 이 Role에 attach한다.
# EC2에는 Role이 1개만 붙으므로 별도 Role을 Instance Profile에 연결하는 대신 기존
# 정책을 이 Role에 attach하는 방식을 쓴다.
resource "aws_iam_role_policy_attachment" "dashboard_finops_read" {
  count      = var.finops_dashboard_resource_read_policy_arn == "" ? 0 : 1
  role       = aws_iam_role.dashboard.name
  policy_arn = var.finops_dashboard_resource_read_policy_arn
}

# ── EC2 인스턴스 ────────────────────────────────────────────────────────

resource "aws_eip" "dashboard" {
  domain = "vpc"
  tags   = { Name = "mp-eip-dashboard" }
}

resource "aws_instance" "dashboard" {
  ami                    = data.aws_ami.al2023_x86.id
  instance_type          = "t3.medium"
  subnet_id              = data.aws_subnet.dashboard.id # NAT와 같은 AZ (AZ간 전송비 회피)
  vpc_security_group_ids = [data.aws_security_group.dashboard.id]
  iam_instance_profile   = aws_iam_instance_profile.dashboard.name

  # 컨테이너 경유 호출(Bedrock·Cost Explorer·DescribeInstances 등)은 IMDS 홉을 하나 더
  # 지난다. hop_limit 1이면 그 호출들이 조용히 실패한다.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 강제
    http_put_response_hop_limit = 2
  }

  # 명시적으로 암호화 — 이 EC2는 런타임 비밀·설정이 내려오는 서버라 계정 기본 EBS
  # 암호화 설정에 의존하지 않고 코드로 강제한다.
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  # 이 태그가 없으면 launch 자체가 막힌다 — guardrail 정책이 RequestTag/Component가
  # 이 값이 아니면 explicit Deny한다. 이후 관리(중지·재시작·태그 변경 등)도 같은 태그
  # 조건으로 걸려 있어 계속 필요하다.
  tags = {
    Name      = "mp-dashboard"
    Component = "finops-dashboard"
  }
}

resource "aws_eip_association" "dashboard" {
  instance_id   = aws_instance.dashboard.id
  allocation_id = aws_eip.dashboard.id
}
