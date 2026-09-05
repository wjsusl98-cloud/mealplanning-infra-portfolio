# Load-test example

Price API의 hotdeals·recommend(캐시 읽기 경로)를 일정 도착률(constant-arrival-rate)로 검증하는 k6 스크립트입니다.
실제 검증에 쓴 스크립트와 시나리오·임계값 구조가 동일하며, 내부 IP·실 도메인만 예시 값으로 치환했습니다.

```bash
IP=127.0.0.1 HOST=example.mealplanning.local RATE=200 DUR=120s k6 run price-api-load.js
```

`hosts` 옵션으로 도메인을 특정 IP에 직접 매핑해, DNS를 거치지 않고 원하는 백엔드/게이트웨이를 지목해 검증합니다.

실제 검증 결과와 병목 분석은 [부하 테스트 요약](../docs/load-test-report.md)에서 확인할 수 있습니다.
