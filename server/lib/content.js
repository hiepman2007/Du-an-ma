import { fail } from './http.js';

const MAX_TEXT = 60000;
const MAX_FILES = 8;

/**
 * Ghep dau vao trung lap nha cung cap (kieu NotebookLM: nhieu nguon cung luc):
 * cac file (dat dau de cache) -> nguon web -> van ban -> yeu cau.
 * files: [{fileId, mimeType, name}]; fileId/mimeType le van nhan (tuong thich ban cu).
 */
export function buildParts({ files, fileId, mimeType, text, sources, instruction }) {
  const all = [...(Array.isArray(files) ? files : [])];
  if (fileId && !all.some((f) => f.fileId === fileId)) all.unshift({ fileId, mimeType });
  const parts = [];
  for (const f of all.slice(0, MAX_FILES)) {
    if (f?.fileId) parts.push({ kind: 'file', fileId: f.fileId, mimeType: f.mimeType });
  }
  if (Array.isArray(sources) && sources.length) {
    const lines = sources.slice(0, 10).map((s, i) => `[W${i + 1}] ${s.title} - ${s.url}\n${s.extract || s.snippet || ''}`).join('\n\n');
    parts.push({ kind: 'text', text: `NGUỒN WEB ĐÃ CHỌN:\n${lines}` });
  }
  if (text) parts.push({ kind: 'text', text: `VĂN BẢN:\n${String(text).slice(0, MAX_TEXT)}` });
  if (parts.length === 0) throw fail(400, 'Thieu nguon: hay them tai lieu, van ban hoac nguon web');
  parts.push({ kind: 'text', text: instruction });
  return parts;
}

export function hasMaterial({ files, fileId, text, sources }) {
  return !!(fileId || text || (Array.isArray(files) && files.length) || (Array.isArray(sources) && sources.length));
}

export function allowedUrlSet(sources) {
  return new Set((sources || []).map((s) => s.url));
}
