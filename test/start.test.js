const { start } = require('../src/server');

test('start() поднимает сервер на указанном порту', async () => {
  const log = jest.spyOn(console, 'log').mockImplementation(() => {});
  const server = start(0);
  await new Promise((resolve) => server.once('listening', resolve));

  const { port } = server.address();
  const res = await fetch(`http://127.0.0.1:${port}/health`);
  expect(res.status).toBe(200);

  await new Promise((resolve) => server.close(resolve));
  process.removeAllListeners('SIGTERM');
  process.removeAllListeners('SIGINT');
  log.mockRestore();
});
