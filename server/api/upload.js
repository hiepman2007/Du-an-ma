import { wrap, fail } from '../lib/http.js';
import { uploadFile } from '../lib/ai.js';

const ALLOWED = new Set(['application/pdf', 'image/png', 'image/jpeg', 'image/webp']);
const MAX_BYTES = 4 * 1024 * 1024; // gioi han body cua Vercel ~4.5MB

// Body: { filename, mimeType, dataBase64 } -> { fileId, mimeType }
export default wrap(async (req, res) => {
  const { filename, mimeType, dataBase64 } = req.body || {};
  if (!dataBase64 || !ALLOWED.has(mimeType)) throw fail(400, 'Chi ho tro PDF hoac anh PNG/JPG/WEBP');
  const buffer = Buffer.from(dataBase64, 'base64');
  if (buffer.length > MAX_BYTES) throw fail(413, 'Tai lieu qua lon (toi da ~4MB). Hay dung PDF ngan hon hoac chup anh tung trang');
  const fileId = await uploadFile({ buffer, filename: filename || 'tai-lieu', mimeType });
  res.status(200).json({ fileId, mimeType });
});
