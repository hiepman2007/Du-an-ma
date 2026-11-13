import { AsyncLocalStorage } from 'node:async_hooks';

const context = new AsyncLocalStorage();
const notebookIdPattern = /^[A-Za-z0-9_-]{1,120}$/;
const userIdPattern = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
const fileLimit = 10 * 1024 * 1024;
const mimeTypes = new Set(['application/pdf', 'image/jpeg', 'image/png', 'image/webp']);
const fileHandles = new Map();

function fail(status, message) {
  return Object.assign(new Error(message), { status, publicMessage: message });
}

export function studyAccountsRequired() {
  return process.env.STUDY_REQUIRE_AUTH === 'true' || Boolean(process.env.SUPABASE_URL);
}

function config() {
  const url = process.env.SUPABASE_URL?.replace(/\/+$/, '');
  const key = process.env.SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw fail(503, 'Dịch vụ tài khoản chưa được cấu hình.');
  return { url, key };
}

async function supabaseRequest(path, { token, secret = false, ...init } = {}) {
  const { url, key } = config();
  const secretKey = process.env.SUPABASE_SECRET_KEY;
  if (secret && !secretKey) throw fail(503, 'Dịch vụ hạn mức chưa được cấu hình.');
  const headers = {
    apikey: secret ? secretKey : key,
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...init.headers,
  };
  try {
    return await fetch(`${url}${path}`, { ...init, headers, signal: AbortSignal.timeout(6000) });
  } catch {
    throw fail(503, 'Chưa kết nối được dịch vụ lưu trữ. Hãy thử lại.');
  }
}

export async function authenticateStudyAccount(req) {
  const authorization = req.headers.authorization;
  const token = typeof authorization === 'string' && /^Bearer ([^\s]+)$/i.exec(authorization)?.[1];
  if (!token) throw fail(401, 'Đăng nhập để sử dụng dịch vụ AI.');
  const response = await supabaseRequest('/auth/v1/user', { token });
  if (response.status === 401 || response.status === 403) throw fail(401, 'Phiên đăng nhập đã hết hạn.');
  if (!response.ok) throw fail(503, 'Chưa xác thực được tài khoản. Hãy thử lại.');
  const user = await response.json();
  if (!userIdPattern.test(user.id || '') || user.is_anonymous === true || !user.email_confirmed_at) {
    throw fail(403, 'Hãy xác nhận email để sử dụng dịch vụ AI.');
  }
  return { id: user.id, token };
}

export function withStudyAccount(account, task) {
  return context.run({ account, notebooks: new Map() }, task);
}

export function currentStudyAccount() {
  return context.getStore()?.account;
}

export async function assertStudyNotebookAccess(body, { required = false } = {}) {
  const state = context.getStore();
  if (!state?.account) return;
  const notebookId = body?.notebook_id ?? body?.notebookId;
  if (notebookId == null && !required) return;
  if (typeof notebookId !== 'string' || !notebookIdPattern.test(notebookId)) throw fail(400, 'Mã sổ học tập không hợp lệ.');
  if (!state.notebooks.has(notebookId)) {
    const query = new URLSearchParams({
      select: 'document', notebook_id: `eq.${notebookId}`, owner_id: `eq.${state.account.id}`, limit: '1',
    });
    const response = await supabaseRequest(`/rest/v1/study_notebooks?${query}`, { token: state.account.token });
    if (!response.ok) throw fail(503, 'Chưa đọc được sổ học tập. Hãy thử lại.');
    const notebooks = await response.json();
    if (!notebooks[0]) throw fail(404, 'Không tìm thấy sổ học tập trong tài khoản này.');
    state.notebooks.set(notebookId, notebooks[0].document);
  }
  return state.notebooks.get(notebookId);
}

function positiveLimit(key, fallback) {
  const value = Number(process.env[key]);
  return Number.isSafeInteger(value) && value > 0 && value <= 1_000_000 ? value : fallback;
}

export async function consumeStudyQuota(task, { category = 'model' } = {}) {
  const account = currentStudyAccount();
  if (!account) return;
  const search = category === 'search';
  const prefix = search ? 'STUDY_SEARCH' : 'STUDY_MODEL';
  const response = await supabaseRequest('/rest/v1/rpc/study_reserve_usage', {
    secret: true,
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      p_owner: account.id,
      p_task: task,
      p_category: category,
      p_owner_daily: positiveLimit(`${prefix}_USER_DAILY`, search ? 10 : 30),
      p_project_daily: positiveLimit(`${prefix}_PROJECT_DAILY`, search ? 100 : 200),
      p_project_per_minute: positiveLimit(`${prefix}_PROJECT_PER_MINUTE`, search ? 8 : 12),
    }),
  });
  if (response.status === 429) throw fail(429, 'Đã hết hạn mức cho tác vụ này. Nội dung đã tạo vẫn dùng được.');
  if (!response.ok) throw fail(503, 'Chưa kiểm tra được hạn mức. Hãy thử lại.');
  return await response.json();
}

export async function recordStudyUsage(id, usage) {
  if (!id) return;
  try {
    const response = await supabaseRequest(`/rest/v1/study_usage?id=eq.${id}`, {
      secret: true,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ input_tokens: usage.input, output_tokens: usage.output, cached_tokens: usage.cached }),
    });
    if (!response.ok) console.warn('[study-usage] metrics write failed', response.status);
  } catch {
    console.warn('[study-usage] metrics write failed');
  }
}

function matchesMime(buffer, mimeType) {
  if (mimeType === 'application/pdf') return buffer.subarray(0, 1024).includes(Buffer.from('%PDF-'));
  if (mimeType === 'image/png') return buffer.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  if (mimeType === 'image/jpeg') return buffer.subarray(0, 3).equals(Buffer.from([255, 216, 255]));
  return buffer.toString('ascii', 0, 4) === 'RIFF' && buffer.toString('ascii', 8, 12) === 'WEBP';
}

async function cachedFile(path, metadata, uploadFile) {
  const { mimeType, title } = metadata;
  const account = currentStudyAccount();
  const provider = process.env.AI_PROVIDER || (process.env.OPENAI_API_KEY ? 'openai' : 'gemini');
  const cacheKey = `${provider}:${path}`;
  const now = Date.now();
  const cached = fileHandles.get(cacheKey);
  if (cached?.expiresAt > now) return await cached.promise;
  const promise = (async () => {
    const encodedPath = path.split('/').map(encodeURIComponent).join('/');
    const response = await supabaseRequest(`/storage/v1/object/authenticated/study-sources/${encodedPath}`, { token: account.token });
    if (response.status === 404 || response.status === 403) throw fail(422, 'Không tìm thấy tệp. Hãy đính kèm lại nguồn.');
    if (!response.ok) throw fail(503, 'Chưa đọc được tệp. Hãy thử lại.');
    const announcedSize = Number(response.headers.get('content-length'));
    if (announcedSize > fileLimit) throw fail(413, 'Tệp vượt quá 10 MB.');
    const buffer = Buffer.from(await response.arrayBuffer());
    if (buffer.length > fileLimit) throw fail(413, 'Tệp vượt quá 10 MB.');
    if (!matchesMime(buffer, mimeType)) throw fail(422, 'Định dạng của tệp không khớp với nguồn đã lưu.');
    const [fileId, pages] = await Promise.all([
      uploadFile({ buffer, filename: String(title || 'tai-lieu').slice(0, 150), mimeType }),
      mimeType === 'application/pdf' ? import('./pdf_pages.js').then(({ extractPdfPages }) => extractPdfPages(buffer)) : [],
    ]);
    return { fileId, pages };
  })();
  fileHandles.set(cacheKey, { promise, expiresAt: now + 24 * 60 * 60 * 1000 });
  if (fileHandles.size > 128) fileHandles.delete(fileHandles.keys().next().value);
  try {
    return await promise;
  } catch (error) {
    if (fileHandles.get(cacheKey)?.promise === promise) fileHandles.delete(cacheKey);
    throw error;
  }
}

export async function resolveStudyFiles(body, uploadFile) {
  if (!currentStudyAccount()) return body;
  const notebook = await assertStudyNotebookAccess(body, { required: true });
  const requested = Array.isArray(body?.files) ? body.files.slice(0, 8) : [];
  const { fileId, mimeType, ...material } = body;
  if (fileId) throw fail(422, 'Tệp cũ cần được đính kèm lại vào sổ học tập.');
  if (!requested.length) return { ...material, files: [] };
  if (process.env.STUDY_PRIVATE_AI_ENABLED !== 'true') {
    throw fail(422, 'Máy chủ chưa bật xử lý tệp riêng bằng AI. Bạn có thể bỏ chọn tệp để dùng các nguồn khác.');
  }
  const owned = new Map((Array.isArray(notebook?.sources) ? notebook.sources : [])
    .filter((source) => source?.kind === 'file' && !source.removed && source.enabled !== false)
    .map((source) => [source.id, source]));
  const notebookId = body.notebook_id ?? body.notebookId;
  const prefix = `${currentStudyAccount().id}/${notebookId}/`;
  const validated = requested.map((file) => {
    const meta = owned.get(file?.id);
    const path = file?.storage_path ?? file?.storagePath;
    if (!path || typeof path !== 'string' || !meta?.storage_path || file?.fileId) {
      throw fail(422, 'Tệp cũ cần được đính kèm lại vào sổ học tập.');
    }
    if (path !== meta.storage_path || !path.startsWith(prefix) || !notebookIdPattern.test(path.slice(prefix.length))) {
      throw fail(403, 'Tệp không thuộc sổ học tập hoặc đang bị tắt.');
    }
    if (!mimeTypes.has(meta.mimeType)) throw fail(400, 'Loại tệp chưa được hỗ trợ.');
    return { meta, path };
  });
  const files = await Promise.all(validated.map(async ({ meta, path }) => ({
    id: meta.id,
    name: meta.title,
    mimeType: meta.mimeType,
    ...await cachedFile(path, meta, uploadFile),
  })));
  return { ...material, files };
}
