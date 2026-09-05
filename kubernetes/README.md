# Kubernetes manifests

비공개 GitOps 정본 레포에서 운영한 Kustomize·Argo CD 구성 중, 제가 담당한 관측 이관과
Operations API 배포에 해당하는 파일을 그대로 옮겼습니다. 리소스 종류·설정 구조·주석까지
실제 그대로이며, 이미지 레지스트리·계정 ID·내부 IP·Secret 값만 변수·Secret 참조로
치환했습니다.

| 경로 | 내용 |
| --- | --- |
| `observability/loki/loki-application.yaml` | Loki(SingleBinary) ArgoCD Application — S3 백엔드 전환, DNS 하이재킹 회피, 노드 배치 근거 |
| `observability/tempo/tempo-application.yaml` | Tempo ArgoCD Application — 트레이스 저장소, liveness/readiness 분리 근거(실제 장애 이력 포함) |
| `observability/tempo/telemetry-tracing.yaml` | Istio 메시 트레이싱을 Tempo OTLP로 연결하는 Telemetry CR |
| `observability/alloy/alloy-application.yaml` | Alloy DaemonSet ArgoCD Application — 노드별 파드 로그 discovery·relabel·Loki push |
| `observability/prometheus/app-symptom-rule.yaml` | 유저 경로 SYMPTOM 알람 — 검색 0건 장애를 계기로 CAUSE 알람의 사각을 메운 설계 |
| `observability/prometheus/service-monitor.yaml` | 앱 서비스 지표 수집 — Istio mTLS 메시 안에서 병합 엔드포인트로 우회하는 relabel |
| `operations/` | Operations API의 Deployment·Service·Kustomization |
