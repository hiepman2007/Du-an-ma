import { timingSafeEqual } from 'node:crypto';
import { assertStudyNotebookAccess, authenticateStudyAccount, resolveStudyFiles, studyAccountsRequired, withStudyAccount } from './account.js';

const hits = new Map();

// Khi chua bat tai khoan (SUPABASE_URL/STUDY_REQUIRE_AUTH): kiem tra APP_TOKEN chung + gioi han toc do,
// ca tren Vercel (ban demo hackathon) lan may cuc bo. Bat tai khoan thi chuyen sang xac thuc tung nguoi dung.
function guardAppToken(req) {
  const expected = process.env.APP_TOKEN;
  if (!expected) throw fail(503, 'Máy chủ chưa cấu hình APP_TOKEN hoặc dịch vụ tài khoản.');
  const supplied = req.headers['x-app-token'];
  const token = typeof supplied === 'string' ? Buffer.from(supplied) : Buffer.alloc(0);
  const expectedBytes = Buffer.from(expected);
  if (token.length !== expectedBytes.length || !timingSafeEqual(token, expectedBytes)) {
    throw fail(401, 'Không có quyền truy cập.');
  }
  const limit = Number(process.env.RATE_LIMIT_PER_MIN || 30);
  const minute = Math.floor(Date.now() / 60000);
  const count = (hits.get(minute) || 0) + 1;
  hits.clear();
  hits.set(minute, count);
  if (count > limit) throw fail(429, 'Quá nhiều yêu cầu. Hãy thử lại sau.');
}

async function prepareCloudRequest(req) {
  const path = (req.url || '').split('?')[0];
  if (path === '/api/upload') throw fail(410, 'Hãy tải tệp vào kho riêng của sổ học tập.');
  if (path === '/api/sources/search' || (path === '/api/ask' && req.body?.webSearch)) {
    throw fail(410, 'Hãy dùng tìm nguồn trong sổ học tập.');
  }
  if (path === '/api/usage') throw fail(404, 'Không tìm thấy.');
  if (!req.body || typeof req.body !== 'object') return;
  await assertStudyNotebookAccess(req.body, { required: /^\/api\/study\/(ask|artifact|outline|lesson)$/.test(path) });
  if (!path.startsWith('/api/study/') && (req.body.fileId || req.body.files?.length)) {
    const { uploadFile } = await import('./ai.js');
    req.body = await resolveStudyFiles(req.body, uploadFile);
  }
}

export function wrap(handler, { method = 'POST' } = {}) {
  return async (req, res) => {
    const origin = req.headers.origin;
    const allow = (process.env.STUDY_WEB_ORIGINS || '').split(',').map((value) => value.trim()).filter(Boolean);
    if (!studyAccountsRequired() && allow.length === 0) res.setHeader('Access-Control-Allow-Origin', '*');
    if (allow.includes(origin)) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Vary', 'Origin');
    }
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-App-Token');
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
      if (studyAccountsRequired()) {
        const account = await authenticateStudyAccount(req);
        await withStudyAccount(account, async () => {
          requireAdultProviderUse(req);
          await prepareCloudRequest(req);
          await handler(req, res);
        });
      } else {
        guardAppToken(req);
        requireAdultProviderUse(req);
        await handler(req, res);
      }
    } catch (e) {
      const status = e.status && e.status >= 400 && e.status < 600 ? e.status : 500;
      if (status >= 500) console.error('[api]', status, e.name);
      res.status(status).json({ error: e.publicMessage || 'Lỗi máy chủ. Hãy thử lại.' });
    }
  };
}

function requireAdultProviderUse(req) {
  if (req.body?.role !== 'pupil') return;
  const provider = (process.env.AI_PROVIDER || '').toLowerCase();
  if (provider === 'openai' || (provider !== 'gemini' && process.env.OPENAI_API_KEY)) return;
  throw fail(403, 'Chế độ AI hiện dành cho người học từ 18 tuổi. Bạn vẫn có thể mở khóa mẫu.');
}

export function fail(status, message) {
  const e = new Error(message);
  e.status = status;
  e.publicMessage = message;
  return e;
}
