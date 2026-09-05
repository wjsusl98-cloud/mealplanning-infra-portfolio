# Load-test example

Price API의 hotdeals·recommend(캐시 읽기 경로)를 일정 도착률(constant-arrival-rate)로
검증하는 실제 k6 스크립트입니다. 시나리오·임계값·엔드포인트는 실제 검증에 쓴 것 그대로이고,
내부 게이트웨이 IP만 빈 값으로 치환했습니다(실행 시 `IP` 환경변수로 채워 넣습니다).

```bash
k6 run -e IP=<대상 게이트웨이 IP> -e RATE=200 -e DUR=120s price-api-load.js
```

`hosts` 옵션으로 도메인을 특정 IP에 직접 매핑해, DNS를 거치지 않고 원하는 백엔드/게이트웨이를
지목해 검증합니다 — 로드밸런서 앞에서 개별 노드를 짚어 병목을 좁힐 때 씁니다.

실제 검증 결과와 병목 분석은 [부하 테스트 요약](../docs/load-test-report.md)에서 확인할 수 있습니다.
