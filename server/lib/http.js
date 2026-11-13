// Tien ich dung chung cho cac handler: xac thuc token, gioi han toc do, tra loi loi.

const hits = new Map();

export function guard(req, res) {
  const expected = process.env.APP_TOKEN;
  if (!expected) {
    res.status(500).json({ error: 'Server chua cau hinh APP_TOKEN' });
    return false;
  }
  if (req.headers['x-app-token'] !== expected) {
    res.status(401).json({ error: 'Khong co quyen truy cap' });
    return false;
  }
  const limit = Number(process.env.RATE_LIMIT_PER_MIN || 30);
  const minute = Math.floor(Date.now() / 60000);
  const key = `${minute}`;
  const count = (hits.get(key) || 0) + 1;
  hits.clear();
  hits.set(key, count);
  if (count > limit) {
    res.status(429).json({ error: 'Qua nhieu yeu cau, thu lai sau it giay' });
    return false;
  }
  return true;
}

export function wrap(handler, { method = 'POST' } = {}) {
  return async (req, res) => {
    // CORS cho ban web xem thu (app Android khong can). Bao ve that su van la X-App-Token.
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-App-Token');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    if (req.method === 'OPTIONS') {
      res.statusCode = 204;
      res.end();
      return;
    }
    try {
      if (req.method !== method) {
        res.status(405).json({ error: `Chi ho tro ${method}` });
        return;
      }
      if (!guard(req, res)) return;
      await handler(req, res);
    } catch (e) {
      console.error('[error]', e);
      const status = e.status && e.status >= 400 && e.status < 600 ? e.status : 500;
      res.status(status).json({ error: e.publicMessage || 'Loi may chu khi goi AI', detail: String(e.message || e).slice(0, 300) });
    }
  };
}

export function fail(status, message) {
  const e = new Error(message);
  e.status = status;
  e.publicMessage = message;
  return e;
}
