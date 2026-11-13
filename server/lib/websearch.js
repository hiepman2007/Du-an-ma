// Tra cuu web kieu NotebookLM: uu tien cong cu tim kiem cua nha cung cap AI (Google Search / OpenAI web_search),
// neu khong dung duoc (vd Gemini goi mien phi -> 429) thi du phong bang Wikipedia (mien phi, nguon that).
import { generateJson, providerName } from './ai.js';
import { searchWikipedia } from './wiki.js';
import { hostOf, trustOf } from './trust.js';

const DOMAIN_RE = /^[a-z0-9-]+(\.[a-z0-9-]+)+$/i;

/** Ten mien that cua mot chu thich (Gemini co the tra link chuyen huong, khi do title la ten mien goc). */
export function citationDomain(c) {
  const host = hostOf(c.url);
  const isRedirect = host.endsWith('vertexaisearch.cloud.google.com') || host === 'google.com';
  if (!isRedirect) return host;
  const t = (c.title || '').trim().toLowerCase().replace(/^www\./, '');
  return DOMAIN_RE.test(t) ? t : '';
}

/** Chu thich -> nguon hien cho nguoi dung (bo trung, gan nhan tin cay). */
export function citationsToSources(citations, max = 8) {
  const seen = new Set();
  const out = [];
  for (const c of citations || []) {
    const url = String(c.url || '').split('#')[0];
    const domain = citationDomain(c) || hostOf(url);
    if (!url || !domain || seen.has(url)) continue;
    seen.add(url);
    out.push({ title: c.title || domain, url, domain, snippet: c.snippet || '', trust: trustOf(`https://${domain}`) });
    if (out.length >= max) break;
  }
  return out;
}

/**
 * Goi AI co bat tra cuu web. Tra ve { json, web: [nguon], webMode: 'search'|'wikipedia' }.
 * fallbackQuery: tu khoa de tra Wikipedia khi cong cu tim kiem loi.
 */
export async function generateWithWeb({ fallbackQuery, parts, ...args }) {
  try {
    const { json, citations } = await generateJson({ ...args, parts, webSearch: true });
    return { json, web: citationsToSources(citations), webMode: 'search' };
  } catch (e) {
    console.warn(`[websearch] ${providerName()} search loi (${e.status || ''} ${e.publicMessage || e.message}), du phong Wikipedia`);
    const wiki = await searchWikipedia(fallbackQuery, { limit: 4 });
    const extra = wiki.length
      ? [{ kind: 'text', text: `NGUỒN WEB (Wikipedia, vừa tra cứu):\n${wiki.map((w, i) => `[W${i + 1}] ${w.title} - ${w.url}\n${w.extract}`).join('\n\n')}` }]
      : [];
    // Chen nguon web truoc yeu cau cuoi cung.
    const merged = [...parts.slice(0, -1), ...extra, parts[parts.length - 1]];
    const { json } = await generateJson({ ...args, parts: merged, webSearch: false });
    return {
      json,
      web: wiki.map((w) => ({ title: w.title, url: w.url, domain: hostOf(w.url), snippet: w.snippet, trust: trustOf(w.url) })),
      webMode: 'wikipedia',
    };
  }
}
