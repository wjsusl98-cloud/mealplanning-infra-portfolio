import http from 'k6/http';
import { check, sleep } from 'k6';

// BASE_URL=https://example.com RATE=20 DURATION=5m k6 run price-api-load.js
const baseUrl = __ENV.BASE_URL || 'http://localhost:8000';
const rate = Number(__ENV.RATE || 10);
const duration = __ENV.DURATION || '5m';

export const options = {
  scenarios: {
    price_api: {
      executor: 'constant-arrival-rate',
      rate,
      timeUnit: '1s',
      duration,
      preAllocatedVUs: Math.max(rate, 20),
      maxVUs: Math.max(rate * 3, 60),
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1000'],
  },
};

export default function () {
  const response = http.get(`${baseUrl}/api/v1/prices/current`);
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response is under 1 second': (r) => r.timings.duration < 1000,
  });
  sleep(0.1);
}
