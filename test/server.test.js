const { createServer } = require('../src/server');

let server;
let baseUrl;

beforeAll(async () => {
  server = createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  baseUrl = `http://127.0.0.1:${port}`;
});

afterAll(async () => {
  await new Promise((resolve) => server.close(resolve));
});

test('GET /health возвращает 200 OK', async () => {
  const res = await fetch(`${baseUrl}/health`);

  expect(res.status).toBe(200);
  expect(res.headers.get('content-type') ?? '').toMatch(/application\/json/);

  const body = await res.json();
  expect(body).toEqual({ status: 'ok' });
});
