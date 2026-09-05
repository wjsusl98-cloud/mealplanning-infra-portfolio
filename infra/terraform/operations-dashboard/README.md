# operations-dashboard — 대시보드 EC2 Terraform 스택

FinOps·Operations AI 대시보드 EC2 1대를 만드는 실제 Terraform 모듈입니다. 실제로 쓴 리소스
구조·IAM 권한 경계·보안 하드닝을 그대로 담았고, VPC ID·계정 ID·state 백엔드처럼 조직에
종속된 값만 변수/데이터소스 조회로 남겨뒀습니다(값 자체는 포함하지 않음).

네트워크(VPC·EKS·ECR)를 관리하는 플랫폼 스택과 완전히 분리돼 있습니다 — 이 스택은 그
리소스들을 **이름으로 조회만** 하고(`data.tf`), 재생성하거나 지우지 않습니다.

## 다루는 것

- **최소권한 IAM**: permissions boundary로 상한을 걸고, Bedrock·Secrets Manager·SSM
  Parameter Store를 각각 필요한 리소스 경로로만 좁힌 role 정책.
- **Bedrock Guardrail의 tag-on-create ABAC**: `CreateGuardrail`은 리소스 단위 권한을
  지원하지 않아 `Resource: "*"` + `aws:RequestTag` 조건으로, 기존 리소스 조작은
  `aws:ResourceTag` 조건으로 범위를 좁히는 실제 패턴.
- **EC2 하드닝**: IMDSv2 강제 + hop limit 2(컨테이너 경유 호출 고려), EBS 암호화,
  런칭을 막는 필수 태그(guardrail 정책과 짝을 이룸).

## 사용법

```bash
cp backend.conf.example backend.conf   # profile 값을 본인 프로필로 채운다
terraform init -backend-config=backend.conf
terraform plan  -var="profile=<본인 프로필>"
terraform apply -var="profile=<본인 프로필>"
```

## 알려진 제약 — Athena·Glue

이 EC2 Role의 permissions boundary는 `athena:*`·`glue:*`를 포함하지 않습니다.
`dashboard_finops_cost_read`에 Athena 권한을 넣어도 경계와의 교집합이 비어 실질적으로
동작하지 않습니다(배포 후 조용히 AccessDenied) — 상세 비용 조회는 사람이 별도 프로필로
직접 실행하는 경로로 대체합니다.
