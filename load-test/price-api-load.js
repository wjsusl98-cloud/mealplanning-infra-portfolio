// Stage2 — Price API 캐시 읽기 부하 (hotdeals + recommend).
// matview refresh가 이 캐시를 flush → 미스 폭증(스탬피드) + PG REFRESH 경합이 여기서 드러남.
// 인증 불필요(공개 GET).
//
// k6의 `hosts` 옵션으로 도메인→IP를 직접 매핑해 DNS를 거치지 않고 특정 노드/게이트웨이로
// 트래픽을 보낸다 — 로드밸런서 앞에서 개별 백엔드를 지목해 검증할 때 씀.
//
// 실행: IP=<대상 IP> HOST=<대상 도메인> RATE=200 DUR=120s k6 run price-api-load.js
// 안전: 오류율 10% 초과 또는 p95 3s 초과 시 자동 중단.

import http from 'k6/http';
import { check } from 'k6';

const IP   = __ENV.IP   || '127.0.0.1';
const HOST = __ENV.HOST || 'example.mealplanning.local';
const RATE = Number(__ENV.RATE || 200);

export const options = {
  hosts: { [HOST]: IP },
  insecureSkipTLSVerify: true,
  scenarios: {
    price: {
      executor: 'constant-arrival-rate',
      rate: RATE,
      timeUnit: '1s',
      duration: __ENV.DUR || '120s',
      preAllocatedVUs: 50,
      maxVUs: 300,
    },
  },
  thresholds: {
    'http_req_duration{name:hotdeals}': ['p(95)<2000'],
    'http_req_duration{name:recommend}': ['p(95)<2000'],
    http_req_failed: [{ threshold: 'rate<0.10', abortOnFail: true, delayAbortEval: '15s' }],
    http_req_duration: [{ threshold: 'p(95)<3000', abortOnFail: true, delayAbortEval: '15s' }],
  },
};

export default function () {
  if (Math.random() < 0.5) {
    const r = http.get(`https://${HOST}/api/prices/hotdeals?limit=20`, { tags: { name: 'hotdeals' } });
    check(r, { 'hotdeals 200': (res) => res.status === 200 });
  } else {
    const r = http.get(`https://${HOST}/api/prices/recommend?limit=20`, { tags: { name: 'recommend' } });
    check(r, { 'recommend 200': (res) => res.status === 200 });
  }
}
