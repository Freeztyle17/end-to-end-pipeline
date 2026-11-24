const request = require('supertest');
const { createServer } = require('../src/server');

const app = createServer();

test('GET /health возвращает 200 OK', async () => {
  const res = await request(app).get('/health');

  expect(res.status).toBe(200);
  expect(res.headers['content-type']).toMatch(/application\/json/);
  expect(res.body).toEqual({ status: 'ok' });
});

test('GET / возвращает версию приложения', async () => {
  const res = await request(app).get('/');

  expect(res.status).toBe(200);
  expect(res.body).toMatchObject({ app: 'end-to-end-pipeline' });
  expect(typeof res.body.version).toBe('string');
});

test('неизвестный путь возвращает 404', async () => {
  const res = await request(app).get('/nope');

  expect(res.status).toBe(404);
  expect(res.body).toEqual({ error: 'Not Found' });
});

test('POST /health возвращает 404', async () => {
  const res = await request(app).post('/health');

  expect(res.status).toBe(404);
});
