# Operations analysis

이상징후를 탐지하고, 관련 경보를 하나의 장애 조사 건으로 묶는 운영 분석 로직입니다.

- `anomaly_analyzer.py`: 이동 기준선과 Z-score·MAD·변화율·연속 발생 조건을 함께 평가
- `incident_correlator.py`: 시간·서비스·Pod·서비스 의존성 기준으로 관련 경보를 그룹화
- `tests/`: 탐지와 상관분석의 회귀 테스트

Bedrock은 이 로직이 수집·선별한 조사 근거를 바탕으로 원인 분석 초안을 작성합니다. 장애 원인의 최종 판단은 자동화가 아닌 운영자가 수행합니다.
