import { wrap, fail } from '../lib/http.js';
import { uploadFile } from '../lib/ai.js';
import { extractPdfPages } from '../lib/pdf_pages.js';

const ALLOWED = new Set(['application/pdf', 'image/png', 'image/jpeg', 'image/webp']);
const MAX_BYTES = 3 * 1024 * 1024; // Base64 overhead must fit Vercel's 4.5 MB body.

// Body: { filename, mimeType, dataBase64 } -> { fileId, mimeType, pages }
export default wrap(async (req, res) => {
  const { filename, mimeType, dataBase64 } = req.body || {};
  if (typeof dataBase64 !== 'string' || !dataBase64 || !ALLOWED.has(mimeType)) throw fail(400, 'Chỉ hỗ trợ PDF hoặc ảnh PNG/JPG/WEBP.');
  const buffer = Buffer.from(dataBase64, 'base64');
  if (buffer.length > MAX_BYTES) throw fail(413, 'Tài liệu quá lớn (tối đa 3 MB khi chạy thử cục bộ).');
  if (!buffer.length) throw fail(400, 'Tệp tải lên không có dữ liệu.');
  const [fileId, pages] = await Promise.all([
    uploadFile({ buffer, filename: typeof filename === 'string' ? filename.slice(0, 180) : 'tai-lieu', mimeType }),
    mimeType === 'application/pdf' ? extractPdfPages(buffer) : [],
  ]);
  res.status(200).json({ fileId, mimeType, pages });
});
