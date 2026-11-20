const { test, before, after } = require('node:test');
const assert = require('node:assert');
const { createServer } = require('../src/server');

let server;
let baseUrl;

before(async () => {
  server = createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  baseUrl = `http://127.0.0.1:${port}`;
});

after(async () => {
  await new Promise((resolve) => server.close(resolve));
});

test('GET /health возвращает 200 OK', async () => {
  const res = await fetch(`${baseUrl}/health`);

  assert.strictEqual(res.status, 200);
  assert.match(res.headers.get('content-type') ?? '', /application\/json/);

  const body = await res.json();
  assert.deepStrictEqual(body, { status: 'ok' });
});