# Operations dashboard Terraform example

Operations API가 EC2에서 실행될 때 필요한 IAM 권한과 EKS 노드 보안 그룹에서의 API 접근 규칙을 보여주는 공개용 모듈입니다.

실제 VPC, 서브넷, 계정 ID, 모델 ARN, 상태 저장소는 환경별 Terraform 변수와 원격 상태로 관리하므로 포함하지 않았습니다.
