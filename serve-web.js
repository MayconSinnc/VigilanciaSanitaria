const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = Number(process.env.PORT) || 8080;
const HOST = process.env.HOST || '0.0.0.0';
const BACKEND_HOST = process.env.BACKEND_HOST || '127.0.0.1';
const BACKEND_PORT = Number(process.env.BACKEND_PORT) || 3000;
const WEB_DIR = path.join(__dirname, 'mobile', 'web');
const BUILD_WEB_DIR = path.join(__dirname, 'mobile', 'build', 'web');

const API_PROXY_PREFIXES = ['/auth', '/api', '/inspecoes', '/cnpj', '/epublica', '/health'];

function resolvePublicDir() {
  const buildBootstrap = path.join(BUILD_WEB_DIR, 'flutter_bootstrap.js');
  if (fs.existsSync(buildBootstrap)) return BUILD_WEB_DIR;
  return WEB_DIR;
}

const PUBLIC_DIR = resolvePublicDir();
const STATIC_ASSET_EXT = /\.(js|mjs|css|wasm|json|webmanifest|png|jpg|jpeg|gif|svg|ico|woff2?|ttf|map)$/i;

function resolveContentType(filePath) {
  if (filePath.endsWith('.js')) return 'application/javascript';
  if (filePath.endsWith('.css')) return 'text/css';
  if (filePath.endsWith('.wasm')) return 'application/wasm';
  if (filePath.endsWith('.png')) return 'image/png';
  if (filePath.endsWith('.svg')) return 'image/svg+xml';
  if (filePath.endsWith('.ico')) return 'image/x-icon';
  if (filePath.endsWith('manifest.json') || filePath.endsWith('.webmanifest')) {
    return 'application/manifest+json';
  }
  if (filePath.endsWith('.json')) return 'application/json';
  return 'text/html';
}

function resolveExtraHeaders(filePath) {
  if (filePath.includes('flutter_service_worker.js')) {
    return {
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Service-Worker-Allowed': '/',
    };
  }
  if (filePath.endsWith('manifest.json')) {
    return { 'Cache-Control': 'no-cache' };
  }
  return {};
}

function shouldProxyApi(urlPath) {
  return API_PROXY_PREFIXES.some((p) => urlPath === p || urlPath.startsWith(`${p}/`));
}

function proxyToBackend(req, res) {
  const url = new URL(req.url || '/', `http://${BACKEND_HOST}:${BACKEND_PORT}`);
  const headers = { ...req.headers, host: `${BACKEND_HOST}:${BACKEND_PORT}` };
  delete headers['transfer-encoding'];

  const options = {
    hostname: BACKEND_HOST,
    port: BACKEND_PORT,
    path: `${url.pathname}${url.search}`,
    method: req.method,
    headers,
  };

  const proxyReq = http.request(options, (proxyRes) => {
    const outHeaders = { ...proxyRes.headers };
    res.writeHead(proxyRes.statusCode || 502, outHeaders);
    proxyRes.pipe(res);
  });

  proxyReq.on('error', (err) => {
    console.error('Erro no proxy da API:', err.message);
    res.writeHead(502, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Backend indisponível. Verifique se o servidor na porta 3000 está rodando.');
  });

  req.pipe(proxyReq);
}

function serveStatic(req, res) {
  const urlPath = (req.url || '/').split('?')[0];
  const relPath = urlPath === '/' ? 'index.html' : urlPath.replace(/^\//, '');
  const filePath = path.join(PUBLIC_DIR, relPath);

  const normalizedPublic = path.resolve(PUBLIC_DIR);
  const normalizedFile = path.resolve(filePath);
  if (!normalizedFile.startsWith(normalizedPublic + path.sep) && normalizedFile !== normalizedPublic) {
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    res.end('Forbidden');
    return;
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      const isStaticAsset = STATIC_ASSET_EXT.test(urlPath);
      if (err.code === 'ENOENT' && !isStaticAsset && urlPath !== '/') {
        fs.readFile(path.join(PUBLIC_DIR, 'index.html'), (err2, data2) => {
          if (err2) {
            res.writeHead(404, { 'Content-Type': 'text/plain' });
            res.end('Not Found');
            return;
          }
          res.writeHead(200, { 'Content-Type': 'text/html' });
          res.end(data2);
        });
        return;
      }

      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Not Found');
      return;
    }

    const contentType = resolveContentType(filePath);
    const extraHeaders = resolveExtraHeaders(filePath);
    res.writeHead(200, { 'Content-Type': contentType, ...extraHeaders });
    res.end(data);
  });
}

const server = http.createServer((req, res) => {
  const urlPath = (req.url || '/').split('?')[0];
  if (shouldProxyApi(urlPath)) {
    proxyToBackend(req, res);
    return;
  }
  serveStatic(req, res);
});

server.listen(PORT, HOST, () => {
  console.log(`Frontend rodando em http://${HOST}:${PORT}`);
  console.log(`Acesso local: http://localhost:${PORT}`);
  console.log(`API (proxy): mesma URL — encaminha para http://${BACKEND_HOST}:${BACKEND_PORT}`);
  console.log('PWA: manifest.json + flutter_service_worker.js (instale via Chrome/Edge: menu > Instalar app)');
  const os = require('os');
  const nets = os.networkInterfaces();
  for (const name of Object.keys(nets)) {
    for (const net of nets[name] || []) {
      if (net.family === 'IPv4' && !net.internal) {
        console.log(`Acesso na rede: http://${net.address}:${PORT}`);
      }
    }
  }
  console.log(`Servindo arquivos de: ${PUBLIC_DIR}`);
  if (!fs.existsSync(path.join(PUBLIC_DIR, 'main.dart.js'))) {
    console.warn('AVISO: main.dart.js ausente. Execute: flutter build web --release (pasta mobile)');
  }
});
