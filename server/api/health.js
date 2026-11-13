import { wrap } from '../lib/http.js';

export default wrap(async (req, res) => {
  res.status(200).json({ ok: true, time: new Date().toISOString() });
}, { method: 'GET' });
