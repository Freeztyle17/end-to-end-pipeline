const http = require('http');

const APP_VERSION = process.env.APP_VERSION || 'dev';

function sendJson(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

function createServer() {
  return http.createServer((req, res) => {
    if (req.method === 'GET' && req.url === '/health') {
      return sendJson(res, 200, { status: 'ok' });
    }

    if (req.method === 'GET' && req.url === '/') {
      return sendJson(res, 200, {
        app: 'end-to-end-pipeline',
        version: APP_VERSION,
        hostname: require('os').hostname(),
      });
    }

    return sendJson(res, 404, { error: 'Not Found' });
  });
}

function start(port = process.env.PORT || 3000) {
  const server = createServer();
  server.listen(port, () => {
    console.log(`Server listening on http://localhost:${server.address().port}`);
  });

  const shutdown = () => server.close(() => process.exit(0));
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
  return server;
}

if (require.main === module) {
  start();
}

module.exports = { createServer, start, APP_VERSION };
