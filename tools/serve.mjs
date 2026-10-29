// node tools/serve.mjs [port] — minimal static server for local play (ES modules need http, not file://).
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const port = +(process.env.PORT ?? process.argv[2] ?? 5173);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.css': 'text/css', '.md': 'text/plain' };

createServer(async (req, res) => {
  const path = normalize(decodeURIComponent(new URL(req.url, 'http://x').pathname)).replace(/^([/\\])+/, '');
  if (path.startsWith('..')) return res.writeHead(403).end();
  try {
    let body = await readFile(join(root, path || 'index.html'));
    if ((!path || path === 'index.html') && !body.toString().startsWith('<!doctype')) body = `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">${body}`;
    res.writeHead(200, { 'content-type': types[extname(path || 'index.html')] ?? 'application/octet-stream', 'cache-control': 'no-store' }).end(body);
  } catch {
    res.writeHead(404).end('Not found');
  }
}).listen(port, () => console.log(`Cut the Deck at http://localhost:${port}`));
