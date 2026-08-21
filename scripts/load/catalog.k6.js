import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    catalog: {
      executor: 'ramping-arrival-rate',
      startRate: 50,
      timeUnit: '1s',
      preAllocatedVUs: 100,
      maxVUs: 500,
      stages: [
        { duration: '30s', target: 200 },
        { duration: '1m', target: 1000 },
        { duration: '30s', target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<300'],
  },
};

const baseUrl = __ENV.BASE_URL ?? 'http://localhost:3000/api';

export default function () {
  const products = http.get(`${baseUrl}/catalog/products?page=1&limit=20`);
  check(products, {
    'products status 200': (r) => r.status === 200,
  });

  const categories = http.get(`${baseUrl}/catalog/categories`);
  check(categories, {
    'categories status 200': (r) => r.status === 200,
  });

  sleep(0.1);
}
