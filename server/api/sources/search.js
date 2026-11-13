import { wrap, fail } from '../../lib/http.js';
import { generateJson } from '../../lib/ai.js';
import { sourcesSchema } from '../../lib/schemas.js';
import { SOURCES_SYSTEM } from '../../lib/prompts.js';
import { hostOf, trustOf } from '../../lib/trust.js';

const DOMAIN_RE = /^[a-z0-9-]+(\.[a-z0-9-]+)+$/i;

/** Ten mien that cua mot chu thich. Gemini co the tra link chuyen huong cua Google, khi do title la ten mien goc. */
export function citationDomain(c) {
  const host = hostOf(c.url);
  const isRedirect = host.endsWith('vertexaisearch.cloud.google.com') || host === 'google.com';
  if (!isRedirect) return host;
  const t = (c.title || '').trim().toLowerCase().replace(/^www\./, '');
  return DOMAIN_RE.test(t) ? t : '';
}

/**
 * Chi giu nguon do cong cu tim kiem tra ve: URL nam trong chu thich,
 * hoac cung ten mien voi mot chu thich (khi chu thich la link chuyen huong).
 */
export function pickSources(listed, citations, max = 6) {
  const citedUrls = new Map(citations.map((c) => [c.url.split('#')[0], c]));
  const citedDomains = new Set(citations.map(citationDomain).filter(Boolean));
  const seen = new Set();
  const usedDomains = new Set();
  const out = [];
  for (const s of listed || []) {
    const url = (s.url || '').split('#')[0];
    const host = hostOf(url);
    if (!host || seen.has(url)) continue;
    if (!citedUrls.has(url) && !citedDomains.has(host)) continue;
    seen.add(url);
    usedDomains.add(host);
    out.push({ title: s.title || citedUrls.get(url)?.title || host, url, domain: host, snippet: s.snippet || '', trust: trustOf(url) });
  }
  for (const c of citations) {
    if (out.length >= max) break;
    const url = c.url.split('#')[0];
    const domain = citationDomain(c);
    if (!domain || seen.has(url) || usedDomains.has(domain)) continue;
    seen.add(url);
    usedDomains.add(domain);
    out.push({ title: c.title || domain, url, domain, snippet: '', trust: trustOf(`https://${domain}`) });
  }
  out.sort((a, b) => (a.trust === 'trusted' ? 0 : 1) - (b.trust === 'trusted' ? 0 : 1));
  return out.slice(0, max);
}

// Body: { topic, role } -> { sources: [{title,url,domain,snippet,trust}] }
export default wrap(async (req, res) => {
  const { topic } = req.body || {};
  if (!topic || String(topic).length > 300) throw fail(400, 'Hay nhap chu de (toi da 300 ky tu)');
  const { json, citations } = await generateJson({
    step: 'sources',
    kind: 'small',
    system: SOURCES_SYSTEM,
    parts: [{ kind: 'text', text: `Chu de can tim tai lieu hoc tap: ${topic}` }],
    schemaName: 'sources',
    schema: sourcesSchema,
    webSearch: true,
  });
  res.status(200).json({ sources: pickSources(json.sources, citations) });
});
