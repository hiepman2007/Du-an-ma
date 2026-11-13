import { wrap, fail } from '../../lib/http.js';
import { sourcesSchema } from '../../lib/schemas.js';
import { SOURCES_SYSTEM } from '../../lib/prompts.js';
import { hostOf, trustOf } from '../../lib/trust.js';
import { generateWithWeb, citationDomain } from '../../lib/websearch.js';
import { queriesFor } from '../../lib/wiki.js';

export { citationDomain };

/**
 * Chi giu nguon do cong cu tim kiem tra ve: URL nam trong chu thich,
 * hoac cung ten mien voi mot chu thich (khi chu thich la link chuyen huong).
 */
export function pickSources(listed, citations, max = 8) {
  const citedUrls = new Map(citations.map((c) => [c.url.split('#')[0], c]));
  const citedDomains = new Set(citations.map((c) => c.domain || citationDomain(c)).filter(Boolean));
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
    const domain = c.domain || citationDomain(c);
    if (!domain || seen.has(url) || usedDomains.has(domain)) continue;
    seen.add(url);
    usedDomains.add(domain);
    out.push({ title: c.title || domain, url, domain, snippet: c.snippet || '', trust: trustOf(`https://${domain}`) });
  }
  out.sort((a, b) => (a.trust === 'trusted' ? 0 : 1) - (b.trust === 'trusted' ? 0 : 1));
  return out.slice(0, max);
}

// Body: { topic, role } -> { sources: [{title,url,domain,snippet,trust}], webMode }
// Kieu "Discover" cua NotebookLM: tim nguon tren mang de them vao danh sach nguon cua khoa hoc.
export default wrap(async (req, res) => {
  const { topic } = req.body || {};
  if (!topic || String(topic).length > 300) throw fail(400, 'Hay nhap chu de (toi da 300 ky tu)');
  const { json, web, webMode } = await generateWithWeb({
    step: 'sources',
    kind: 'small',
    system: SOURCES_SYSTEM,
    parts: [{ kind: 'text', text: `Chủ đề cần tìm tài liệu học tập: ${topic}` }],
    schemaName: 'sources',
    schema: sourcesSchema,
    fallbackQuery: queriesFor(topic),
  });
  // Che do Wikipedia: nguon chinh la ket qua tra cuu (da co that); che do search: loc theo chu thich.
  const sources = webMode === 'wikipedia' ? web : pickSources(json.sources, web);
  res.status(200).json({ sources, webMode });
});
