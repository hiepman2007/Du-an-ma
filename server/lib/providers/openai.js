// OpenAI Responses API (fetch, khong thu vien). Nhan "parts" trung lap nha cung cap tu lib/ai.js.
import { fail } from '../http.js';

const BASE = 'https://api.openai.com/v1';

function key() {
  const k = process.env.OPENAI_API_KEY;
  if (!k) throw fail(500, 'Server chua cau hinh OPENAI_API_KEY');
  return k;
}

async function request(path, init) {
  const r = await fetch(BASE + path, { ...init, headers: { Authorization: `Bearer ${key()}`, ...(init.headers || {}) } });
  const text = await r.text();
  let data;
  try { data = JSON.parse(text); } catch { data = { raw: text }; }
  if (!r.ok) {
    console.error('[openai]', r.status, text.slice(0, 500));
    throw fail(r.status === 429 ? 429 : 502, r.status === 429 ? 'OpenAI dang gioi han toc do hoac het credits' : 'OpenAI tra loi loi');
  }
  return data;
}

export async function uploadFile({ buffer, filename, mimeType }) {
  const form = new FormData();
  form.append('purpose', mimeType.startsWith('image/') ? 'vision' : 'user_data');
  form.append('file', new Blob([buffer], { type: mimeType }), filename);
  const data = await request('/files', { method: 'POST', body: form });
  return data.id;
}

function toContent(p) {
  if (p.kind === 'text') return { type: 'input_text', text: p.text };
  return p.mimeType?.startsWith('image/') ? { type: 'input_image', file_id: p.fileId } : { type: 'input_file', file_id: p.fileId };
}

export async function generate({ model, system, parts, schemaName, schema, webSearch }) {
  const body = {
    model,
    input: [
      { role: 'system', content: system },
      { role: 'user', content: parts.map(toContent) },
    ],
    text: { format: { type: 'json_schema', name: schemaName, schema, strict: true } },
  };
  if (webSearch) body.tools = [{ type: 'web_search' }];
  const data = await request('/responses', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  let text = '';
  const citations = [];
  for (const item of data.output || []) {
    if (item.type !== 'message') continue;
    for (const c of item.content || []) {
      if (c.type === 'refusal') throw fail(422, 'AI tu choi yeu cau nay');
      if (c.type !== 'output_text') continue;
      text += c.text;
      for (const a of c.annotations || []) {
        if (a.type === 'url_citation') citations.push({ url: a.url, title: a.title || '' });
      }
    }
  }
  const u = data.usage || {};
  return {
    text,
    citations,
    usage: {
      input: u.input_tokens || 0,
      cached: u.input_tokens_details?.cached_tokens || 0,
      output: u.output_tokens || 0,
    },
  };
}
