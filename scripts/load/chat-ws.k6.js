import ws from 'k6/ws';
import { check } from 'k6';

export const options = {
  vus: 100,
  duration: '2m',
  thresholds: {
    checks: ['rate>0.95'],
  },
};

const baseUrl = __ENV.WS_URL ?? 'ws://localhost:3000';
const token = __ENV.WS_TOKEN ?? 'test-token';

export default function () {
  const url = `${baseUrl}/ws?token=${token}`;

  const response = ws.connect(url, {}, function (socket) {
    socket.on('open', () => {
      socket.send(JSON.stringify(['join', 'demo-chat-id']));
    });

    socket.on('message', () => {
      check(true, { 'message received': () => true });
      socket.close();
    });

    socket.setTimeout(() => socket.close(), 5000);
  });

  check(response, { 'connected': (r) => r && r.status === 101 });
}
