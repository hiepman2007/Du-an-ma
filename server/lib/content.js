import { fail } from './http.js';

const MAX_TEXT = 60000;

/** Ghep dau vao trung lap nha cung cap: tai lieu (dat dau de cache) -> nguon web -> van ban -> yeu cau. */
export function buildParts({ fileId, mimeType, text, sources, instruction }) {
  const parts = [];
  if (fileId) parts.push({ kind: 'file', fileId, mimeType });
  if (Array.isArray(sources) && sources.length) {
    const lines = sources.slice(0, 8).map((s, i) => `[${i + 1}] ${s.title} - ${s.url}\n${s.snippet || ''}`).join('\n\n');
    parts.push({ kind: 'text', text: `NGUON WEB DA CHON:\n${lines}` });
  }
  if (text) parts.push({ kind: 'text', text: `VAN BAN:\n${String(text).slice(0, MAX_TEXT)}` });
  if (!fileId && !text && !(sources && sources.length)) throw fail(400, 'Thieu tai lieu, van ban hoac nguon');
  parts.push({ kind: 'text', text: instruction });
  return parts;
}

export function allowedUrlSet(sources) {
  return new Set((sources || []).map((s) => s.url));
}
