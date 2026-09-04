# Load-test example

Price API의 현재가 조회를 일정 도착률로 검증하는 k6 스크립트입니다. 실제 nGrinder 검증과 같은 요청 성격을 공개용으로 재현한 예시이며, 내부 주소·테스트 계정·비밀번호는 포함하지 않습니다.

```bash
BASE_URL=https://your-service.example RATE=20 DURATION=5m k6 run price-api-load.js
```

실제 검증 결과와 병목 분석은 [부하 테스트 요약](../docs/load-test-report.md)에서 확인할 수 있습니다.
