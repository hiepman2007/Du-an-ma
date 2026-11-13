// Server chay thu cuc bo: node --env-file=.env dev.js  (cong 8787). Tren Vercel khong dung file nay.
import http from 'node:http';

const routes = {
  'GET /api/health': () => import('./api/health.js'),
  'GET /api/usage': () => import('./api/usage.js'),
  'POST /api/upload': () => import('./api/upload.js'),
  'POST /api/sources/search': () => import('./api/sources/search.js'),
  'POST /api/course/outline': () => import('./api/course/outline.js'),
  'POST /api/lesson': () => import('./api/lesson.js'),
  'POST /api/interactive': () => import('./api/interactive.js'),
  'POST /api/explain': () => import('./api/explain.js'),
  'POST /api/simulation': () => import('./api/simulation.js'),
};

http.createServer(async (req, res) => {
  const path = (req.url || '').split('?')[0];
  const load = routes[`${req.method} ${path}`];
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (o) => { res.setHeader('Content-Type', 'application/json; charset=utf-8'); res.end(JSON.stringify(o)); };
  if (!load) return res.status(404).json({ error: 'Khong tim thay' });
  const chunks = [];
  for await (const c of req) chunks.push(c);
  try { req.body = chunks.length ? JSON.parse(Buffer.concat(chunks).toString('utf8')) : {}; } catch { return res.status(400).json({ error: 'JSON khong hop le' }); }
  (await load()).default(req, res);
}).listen(8787, () => console.log('Dev server: http://localhost:8787'));
