// Gemini Interactions API (POST /v1beta/interactions) theo tai lieu aistudio.google.com/docs (11/2026).
import { fail } from '../http.js';

const BASE = 'https://generativelanguage.googleapis.com';
const API_REVISION = '2026-05-20';

function key() {
  const k = process.env.GEMINI_API_KEY;
  if (!k) throw fail(500, 'Server chua cau hinh GEMINI_API_KEY');
  return k;
}

function failFrom(status, text) {
  console.error('[gemini]', status, String(text).slice(0, 500));
  if (status === 429) {
    const quota = /quota/i.test(String(text));
    return fail(429, quota ? 'Key Gemini da het han muc (quota) cho chuc nang nay' : 'Gemini dang gioi han toc do. Doi vai giay roi thu lai');
  }
  if (status === 503) return fail(503, 'Gemini dang qua tai. Thu lai sau it phut');
  return fail(502, 'Gemini tra loi loi');
}

/** Tai file len Gemini Files API (resumable). File duoc giu 48 gio. Tra ve uri lam fileId. */
export async function uploadFile({ buffer, filename, mimeType }) {
  const start = await fetch(`${BASE}/upload/v1beta/files`, {
    method: 'POST',
    headers: {
      'x-goog-api-key': key(),
      'X-Goog-Upload-Protocol': 'resumable',
      'X-Goog-Upload-Command': 'start',
      'X-Goog-Upload-Header-Content-Length': String(buffer.length),
      'X-Goog-Upload-Header-Content-Type': mimeType,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ file: { display_name: filename } }),
  });
  const uploadUrl = start.headers.get('x-goog-upload-url');
  if (!start.ok || !uploadUrl) throw failFrom(start.status, await start.text());
  const done = await fetch(uploadUrl, {
    method: 'POST',
    headers: {
      'Content-Length': String(buffer.length),
      'X-Goog-Upload-Offset': '0',
      'X-Goog-Upload-Command': 'upload, finalize',
    },
    body: buffer,
  });
  const text = await done.text();
  if (!done.ok) throw failFrom(done.status, text);
  const uri = JSON.parse(text)?.file?.uri;
  if (!uri) throw fail(502, 'Gemini khong tra ve file uri');
  return uri;
}

function toBlock(p) {
  if (p.kind === 'text') return { type: 'text', text: p.text };
  return { type: p.mimeType?.startsWith('image/') ? 'image' : 'document', uri: p.fileId, mime_type: p.mimeType || 'application/pdf' };
}

/** Gemini chua chac ho tro anyOf: doi anyOf [object, null] thanh type ["object","null"]. */
export function adaptSchema(s) {
  if (Array.isArray(s)) return s.map(adaptSchema);
  if (!s || typeof s !== 'object') return s;
  if (Array.isArray(s.anyOf) && s.anyOf.length === 2) {
    const nonNull = s.anyOf.find((x) => x.type !== 'null');
    const hasNull = s.anyOf.some((x) => x.type === 'null');
    if (nonNull && hasNull && typeof nonNull.type === 'string') {
      return adaptSchema({ ...nonNull, type: [nonNull.type, 'null'] });
    }
  }
  const out = {};
  for (const [k, v] of Object.entries(s)) out[k] = adaptSchema(v);
  return out;
}

export async function generate({ model, system, parts, schema, webSearch }) {
  const body = {
    model,
    system_instruction: system,
    input: parts.map(toBlock),
    response_format: { type: 'text', mime_type: 'application/json', schema: adaptSchema(schema) },
    store: false,
  };
  if (webSearch) body.tools = [{ type: 'google_search' }];
  // Thu lai khi model qua tai tam thoi (500/502/503/504): cho 2s roi 5s.
  let r, raw;
  for (const wait of [0, 2000, 5000]) {
    if (wait) await new Promise((ok) => setTimeout(ok, wait));
    r = await fetch(`${BASE}/v1beta/interactions`, {
      method: 'POST',
      headers: { 'x-goog-api-key': key(), 'Content-Type': 'application/json', 'Api-Revision': API_REVISION },
      body: JSON.stringify(body),
    });
    raw = await r.text();
    if (r.ok || ![500, 502, 503, 504].includes(r.status)) break;
    console.warn('[gemini] retry after', r.status);
  }
  if (!r.ok) throw failFrom(r.status, raw);
  let data;
  try { data = JSON.parse(raw); } catch { throw fail(502, 'Gemini tra ve du lieu khong doc duoc'); }

  // Lay text cua buoc model_output cuoi cung; gom chu thich url_citation.
  let text = '';
  const citations = [];
  const outputs = (data.steps || []).filter((s) => s.type === 'model_output');
  const last = outputs[outputs.length - 1];
  for (const step of outputs) {
    for (const c of step.content || []) {
      if (c.type !== 'text') continue;
      if (step === last) text += c.text || '';
      for (const a of c.annotations || []) {
        if (a.type === 'url_citation' && a.url) citations.push({ url: a.url, title: a.title || '' });
      }
    }
  }
  const u = data.usage || {};
  return {
    text,
    citations,
    usage: {
      input: u.total_input_tokens || 0,
      cached: u.total_cached_tokens || 0,
      output: (u.total_output_tokens || 0) + (u.total_thought_tokens || 0),
    },
  };
}
