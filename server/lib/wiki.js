// Tra cuu web du phong mien phi: Wikipedia (API cong khai, khong can key).
// Dung khi cong cu tim kiem cua nha cung cap AI khong dung duoc (vd Gemini goi mien phi khong co Google Search).
const UA = 'HocThongMinh/0.1 (education demo app)';

async function wikiSearch(query, lang, limit) {
  const api = `https://${lang}.wikipedia.org/w/api.php`;
  const params = new URLSearchParams({
    action: 'query', format: 'json', origin: '*', generator: 'search', gsrsearch: query, gsrlimit: String(limit),
    prop: 'extracts|info', exintro: '1', explaintext: '1', exsentences: '5', inprop: 'url',
  });
  const r = await fetch(`${api}?${params}`, { headers: { 'User-Agent': UA }, signal: AbortSignal.timeout(8000) });
  if (!r.ok) return [];
  const data = await r.json();
  return Object.values(data?.query?.pages || {})
    .sort((a, b) => (a.index || 0) - (b.index || 0))
    .filter((p) => p.extract && p.extract.length > 80)
    .map((p) => ({
      title: p.title,
      url: p.fullurl || `https://${lang}.wikipedia.org/wiki/${encodeURIComponent(p.title)}`,
      snippet: p.extract.slice(0, 220),
      extract: p.extract.slice(0, 1500),
    }));
}

const QUESTION_WORDS = [
  'là gì', 'là ai', 'sinh năm nào', 'năm nào', 'ở đâu', 'quê ở đâu', 'vì sao', 'tại sao', 'như thế nào', 'thế nào',
  'bao nhiêu', 'khi nào', 'có phải', 'hãy', 'giải thích', 'cho mình', 'cho tôi', 'giúp mình', 'giúp tôi', 'ví dụ',
  'what is', 'who is', 'how', 'why', 'when', 'where', 'explain',
];

// Tu phu / tu hoi khong mang noi dung (bo khi tao tu khoa va khi xet do lien quan).
const STOPWORDS = new Set([
  'và', 'của', 'các', 'những', 'một', 'là', 'ai', 'gì', 'nào', 'người', 'ra', 'được', 'có', 'không', 'thì', 'mà',
  'để', 'cho', 'với', 'trong', 'này', 'đó', 'khi', 'sao', 'vì', 'tại', 'như', 'thế', 'bao', 'nhiêu', 'mình', 'tôi', 'bạn',
  'em', 'hãy', 'giúp', 'về', 'từ', 'đến', 'the', 'a', 'an', 'of', 'and', 'is', 'are', 'who', 'what', 'how', 'why', 'to', 'in',
]);

/** Rut gon cau hoi thanh tu khoa tra cuu: bo tu hoi, tu phu, dau cau, giu toi da 6 tu. */
export function keywordsOf(q) {
  let s = ` ${String(q || '').toLowerCase()} `;
  for (const w of QUESTION_WORDS) s = s.split(` ${w} `).join(' ').split(` ${w}?`).join(' ');
  s = s.replace(/[?!.,;:"“”()]/g, ' ').replace(/\s+/g, ' ').trim();
  return s.split(' ').filter((w) => w && !STOPWORDS.has(w)).slice(0, 6).join(' ');
}

/**
 * Ten rieng: cac tu viet hoa lien nhau (vd "Georg Ohm").
 * Bo tu dau cau dung mot minh neu la tu hoi/tu phu ("Ai", "Vì", "Hãy"...).
 */
export function properNouns(q) {
  const words = String(q || '').replace(/[?!.,;:"“”()]/g, ' ').split(/\s+/).filter(Boolean);
  const groups = [];
  let cur = [];
  let start = 0;
  const flush = () => {
    if (cur.length && !(cur.length === 1 && start === 0) && !(cur.length === 1 && STOPWORDS.has(cur[0].toLowerCase()))) {
      groups.push(cur.join(' '));
    }
    cur = [];
  };
  words.forEach((w, i) => {
    if (/^\p{Lu}/u.test(w) && w.length > 1) {
      if (!cur.length) start = i;
      cur.push(w);
    } else flush();
  });
  flush();
  return groups.sort((a, b) => b.length - a.length)[0] || '';
}

/** Tu khoa chinh (de loc ket qua khong lien quan). */
export function keyTerms(...texts) {
  return [...new Set(texts.join(' ').toLowerCase().replace(/[?!.,;:"“”()]/g, ' ').split(/\s+/).filter((w) => w.length >= 3 && !STOPWORDS.has(w)))];
}

/** Danh sach tu khoa thu lan luot cho mot cau hoi. */
export function queriesFor(question, extra = []) {
  const kw = keywordsOf(question);
  return [properNouns(question), kw, ...extra.filter(Boolean).map((e) => `${kw} ${e}`.trim()), question, ...extra].filter(Boolean);
}

/**
 * Tim tren Wikipedia tieng Viet truoc, thieu thi bo sung tieng Anh.
 * query: chuoi hoac danh sach chuoi thu lan luot (cau hoi, tu khoa, ten bai...).
 */
export async function searchWikipedia(query, { limit = 5 } = {}) {
  const queries = [...new Set((Array.isArray(query) ? query : [query]).map((q) => String(q || '').trim()).filter(Boolean))];
  // Chi giu bai co chua tu khoa chinh cua cau hoi (tranh "Ai" -> "Ai Cap").
  const terms = keyTerms(...queries);
  const relevant = (r) => {
    if (!terms.length) return true;
    const hay = `${r.title} ${r.extract}`.toLowerCase();
    return terms.some((t) => hay.includes(t));
  };
  // Diem lien quan: khop tieu de (x3), khop cum 2 tu lien nhau (x2), khop tu don (x1).
  const words = keywordsOf(queries[0] || '').split(' ').concat(keywordsOf(queries[1] || '').split(' ')).filter(Boolean);
  const bigrams = [...new Set(words.slice(0, -1).map((w, i) => `${w} ${words[i + 1]}`))];
  const score = (r) => {
    const title = r.title.toLowerCase();
    const hay = `${title} ${r.extract.toLowerCase()}`;
    return terms.filter((t) => title.includes(t)).length * 3 + bigrams.filter((b) => hay.includes(b)).length * 2 + terms.filter((t) => hay.includes(t)).length;
  };
  const out = [];
  try {
    for (const q of queries) {
      if (out.length >= 3) break;
      out.push(...(await wikiSearch(q, 'vi', limit)).filter(relevant));
    }
    if (out.length < 3) {
      for (const q of queries) {
        if (out.length >= 3) break;
        out.push(...(await wikiSearch(q, 'en', limit)).filter(relevant));
      }
    }
  } catch (e) {
    console.warn('[wiki]', String(e).slice(0, 200));
  }
  const seen = new Set();
  const uniq = out.filter((x) => !seen.has(x.url) && seen.add(x.url)).map((x) => ({ ...x, _s: score(x) }));
  const top = Math.max(0, ...uniq.map((x) => x._s));
  // Bo bai diem thap (< 50% bai tot nhat), giu thu tu theo diem.
  return uniq
    .filter((x) => x._s >= top * 0.5)
    .sort((a, b) => b._s - a._s)
    .slice(0, limit)
    .map(({ _s, ...x }) => x);
}
