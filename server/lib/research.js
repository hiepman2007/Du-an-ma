import { createHash } from 'node:crypto';
import { isIP } from 'node:net';
import { fail } from './http.js';
import { trustOf } from './trust.js';

const MIT = 'https://ocw.mit.edu/courses/';
const ALGORITHMS = `${MIT}6-006-introduction-to-algorithms-spring-2020/pages/`;
const CALCULUS = `${MIT}18-01sc-single-variable-calculus-fall-2010/pages/1.-differentiation/`;
const MECHANICS = `${MIT}8-01sc-classical-mechanics-fall-2016/pages/`;
const CHEMISTRY = `${MIT}5-111sc-principles-of-chemical-science-fall-2014/pages/`;
const PHET = 'https://phet.colorado.edu/en/simulations/';
const OPENSTAX = 'https://openstax.org/books/';

const searches = {
  lecture: 'university open course lecture notes textbook',
  exam: 'university past exams quizzes exam solutions course',
  practice: 'university practice problems problem sets exercises solutions',
  simulation: 'interactive visualization simulation learning',
};
const categories = Object.keys(searches);

// These short descriptions are written for the app. The original exams and
// interactive resources are linked, while the open texts provide study evidence.
const catalog = [
  {
    topics: /\b(dsa|algorithms?|data structures?|cau truc du lieu|giai thuat|thuat toan|binary search|tim kiem nhi phan|bfs|dfs)\b/,
    entries: [
      ['lecture', 'Open Data Structures — Array-Based Lists', 'Pat Morin', 'https://opendatastructures.org/ods-java/2_Array_Based_Lists.html', 'Array-based lists support constant-time indexed access. Inserting or removing an item in the middle of an array-backed list may shift a number of elements proportional to the distance to the end. A dynamically growing array can resize as capacity runs out.'],
      ['lecture', 'Open Data Structures — Graphs', 'Pat Morin', 'https://opendatastructures.org/ods-java/12_Graphs.html', 'Graph representations include adjacency matrices and adjacency lists. Breadth-first search uses a queue to visit vertices in increasing order of distance from the starting vertex in an unweighted graph. Depth-first search explores a branch before backtracking.'],
      ['exam', 'Đề thi Introduction to Algorithms', 'MIT OpenCourseWare', `${ALGORITHMS}quizzes/`],
      ['practice', 'Bài luyện Introduction to Algorithms', 'MIT OpenCourseWare', `${ALGORITHMS}practice-problems/`],
      ['simulation', 'Mô phỏng tìm kiếm và duyệt đồ thị', 'OpenDSA · Virginia Tech', 'https://opendsa-server.cs.vt.edu/embed'],
    ],
  },
  {
    topics: /\b(toan|toan hoc|giai tich|calculus|mathematics|dao ham|derivative|tich phan)\b/,
    entries: [
      ['lecture', 'Calculus — Định nghĩa đạo hàm', 'OpenStax · Rice University', `${OPENSTAX}calculus-volume-1/pages/3-1-defining-the-derivative`, 'The derivative at a point is the limit of the difference quotient, when that limit exists. It describes the slope of the tangent line and the instantaneous rate of change. A secant line uses two distinct points on the graph.'],
      ['exam', 'Đề thi đạo hàm', 'MIT OpenCourseWare', `${CALCULUS}exam-1/`],
      ['practice', 'Quy tắc đạo hàm và bài luyện', 'MIT OpenCourseWare', `${CALCULUS}part-a-definition-and-basic-rules/`],
      ['simulation', 'Khám phá hệ số góc', 'PhET · University of Colorado Boulder', `${PHET}graphing-lines`],
    ],
  },
  {
    topics: /\b(vat ly|physics|co hoc|mechanics|dong hoc|kinematics|newton|gia toc|nem xien)\b/,
    entries: [
      ['lecture', 'University Physics — Chuyển động với gia tốc không đổi', 'OpenStax · Rice University', `${OPENSTAX}university-physics-volume-1/pages/3-4-motion-with-constant-acceleration`, 'For constant acceleration, final velocity equals initial velocity plus acceleration times elapsed time. Displacement equals initial velocity times time plus half of acceleration times time squared. Choose a sign convention before substituting values.'],
      ['practice', 'Bài tập Cơ học cổ điển', 'MIT OpenCourseWare', `${MECHANICS}assignments/`],
      ['simulation', 'Mô phỏng chuyển động ném xiên', 'PhET · University of Colorado Boulder', `${PHET}projectile-motion`],
    ],
  },
  {
    topics: /\b(hoa hoc|chemistry|lien ket hoa hoc|ionic bonding|phan ung hoa hoc|can bang phuong trinh)\b/,
    entries: [
      ['lecture', 'Chemistry 2e — Liên kết ion', 'OpenStax · Rice University', `${OPENSTAX}chemistry-2e/pages/7-1-ionic-bonding`, 'A cation forms when a neutral atom loses one or more electrons. An anion forms when a neutral atom gains one or more electrons. Ionic bonds arise from electrostatic attraction between ions with opposite charges.'],
      ['exam', 'Đề thi Hóa học đại cương', 'MIT OpenCourseWare', `${CHEMISTRY}exams/`],
      ['simulation', 'Mô phỏng cân bằng phương trình hóa học', 'PhET · University of Colorado Boulder', `${PHET}balancing-chemical-equations`],
    ],
  },
];

const stableId = (url) => `web:${createHash('sha256').update(url).digest('hex').slice(0, 24)}`;
const trim = (value, limit) => typeof value === 'string' ? value.trim().slice(0, limit) : '';
const normalize = (value) => value.toLowerCase().normalize('NFD').replace(/\p{M}/gu, '').replace(/đ/g, 'd');

export function canonicalUrl(raw) {
  if (typeof raw !== 'string' || raw.length > 2048) return '';
  try {
    const url = new URL(raw);
    const host = url.hostname.toLowerCase();
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.port ||
        !host.includes('.') || host.startsWith('[') || isIP(host) || /\.(local|localhost|internal|test|invalid|example)$/i.test(host)) return '';
    url.hash = '';
    for (const key of [...url.searchParams.keys()]) {
      if (/^(utm_.*|fbclid|gclid)$/i.test(key)) url.searchParams.delete(key);
    }
    url.searchParams.sort();
    return url.href;
  } catch {
    return '';
  }
}

function asSource({ url, title, category, publisher, snippet = '', extract = '', now }) {
  const domain = new URL(url).hostname.replace(/^www\./, '');
  return {
    id: stableId(url), url, domain, title: trim(title, 180) || domain, category,
    publisher: trim(publisher, 180) || domain,
    snippet: trim(snippet, 400),
    extract: trim(extract, 1800),
    retrieved_at: now.toISOString(),
    trust: publisher ? 'trusted' : trustOf(url),
  };
}

function catalogSources(topic, now) {
  const normalized = normalize(topic);
  const entries = catalog.filter(({ topics }) => topics.test(normalized)).flatMap(({ entries }) => entries);
  return entries.map(([category, title, publisher, url, extract]) =>
    asSource({ url, title, category, publisher, extract, snippet: extract, now }));
}

function queryText(value, limit) {
  return trim(value, limit).replace(/https?:\/\/\S+|[\w.+-]+@[\w.-]+\.[a-z]+/gi, '')
    .replace(/[^\p{L}\p{M}\p{N}\s()&+\-]/gu, ' ').replace(/\s+/g, ' ').trim();
}

export function researchQueries(topic, scope = '') {
  const safeTopic = queryText(topic, 180);
  const safeScope = queryText(scope, 120);
  if (!safeTopic) throw fail(400, 'Hãy nhập chủ đề học cần tìm nguồn.');
  const terms = [safeTopic, safeScope].filter(Boolean).join(' ');
  return Object.entries(searches).map(([category, hint]) => ({ category, query: `${terms} ${hint}` }));
}

async function tavily(path, body, { key, fetcher }) {
  const response = await fetcher(`https://api.tavily.com/${path}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(9000),
  });
  if (!response.ok) throw fail(response.status === 429 ? 429 : 502, 'Dịch vụ tìm nguồn tạm thời chưa phản hồi.');
  const data = await response.json();
  if (!Array.isArray(data.results)) throw fail(502, 'Dịch vụ tìm nguồn trả về dữ liệu không hợp lệ.');
  return data.results;
}

function validExam(entry, url) {
  return /\b(exam|exams|quiz|quizzes|midterm|final|de thi)\b/.test(normalize(`${entry.title || ''} ${new URL(url).pathname}`)) &&
    (/\.(edu|edu\.vn|ac\.uk|ac\.vn|ac\.jp|edu\.au|gov|gov\.vn)$/i.test(new URL(url).hostname));
}

function missingCategories(sources) {
  return categories.filter((category) => !sources.some((source) => source.category === category));
}

const defaults = () => ({ key: process.env.TAVILY_API_KEY, fetcher: fetch, now: new Date(), reserve: async () => {} });

export async function findStudySources({ topic, scope } = {}, options = {}) {
  const config = { ...defaults(), ...options };
  const queries = researchQueries(topic, scope);
  const known = catalogSources(topic, config.now);
  const fallback = { sources: known, missing: missingCategories(known), mode: known.length ? 'catalog' : 'off' };
  if (!config.key) return fallback;

  try {
    await config.reserve();
  } catch (error) {
    if (error.status === 429 && known.length) return { ...fallback, mode: 'partial' };
    throw error;
  }

  const results = await Promise.allSettled(queries.map(async ({ category, query }) => {
    const found = await tavily('search', {
      query, search_depth: 'basic', max_results: 4, include_answer: false, include_raw_content: false,
    }, config);
    return found.flatMap((entry) => {
      const url = canonicalUrl(entry?.url);
      if (!url || (category === 'exam' && !validExam(entry, url))) return [];
      return [{ url, title: entry.title, snippet: entry.content, category, score: Number(entry.score) || 0 }];
    }).sort((a, b) => Number(trustOf(b.url) === 'trusted') - Number(trustOf(a.url) === 'trusted') || b.score - a.score);
  }));

  const found = new Map();
  for (const result of results) {
    if (result.status !== 'fulfilled') continue;
    let added = 0;
    for (const entry of result.value) {
      if (found.has(entry.url)) continue;
      found.set(entry.url, entry);
      if (++added === 2) break;
    }
  }
  let partial = results.some((result) => result.status === 'rejected');
  const toRead = [...found.values()].filter(({ category }) => ['lecture', 'practice'].includes(category));
  if (toRead.length) {
    try {
      const excerpts = await tavily('extract', {
        urls: toRead.map(({ url }) => url),
        query: queryText(topic, 180),
        extract_depth: 'basic', chunks_per_source: 1, format: 'text', timeout: 8,
      }, config);
      const requested = new Set(toRead.map(({ url }) => url));
      const read = new Set();
      for (const entry of excerpts) {
        const url = canonicalUrl(entry?.url);
        if (!requested.has(url) || !trim(entry.raw_content, 1800)) continue;
        found.get(url).extract = entry.raw_content;
        read.add(url);
      }
      partial ||= read.size !== requested.size;
    } catch {
      partial = true;
    }
  }

  const sources = [...found.values()].map((entry) => asSource({ ...entry, now: config.now }));
  for (const entry of known) {
    if (!found.has(entry.url)) sources.push(entry);
    else if (entry.extract) {
      const index = sources.findIndex(({ url }) => url === entry.url);
      if (!sources[index].extract) sources[index] = entry;
    }
  }
  const missing = missingCategories(sources);
  const mode = partial || missing.length ? 'partial' : 'tavily';
  return { sources, missing, mode };
}

export async function readStudyUrl(rawUrl, options = {}) {
  const config = { ...defaults(), ...options };
  const url = canonicalUrl(rawUrl);
  if (!url) throw fail(400, 'Chỉ hỗ trợ liên kết HTTP hoặc HTTPS công khai.');
  const match = catalogSources('dsa toan vat ly hoa hoc', config.now).find((entry) => entry.url === url);
  if (match) return match;

  let extract = '';
  let title = '';
  if (config.key) {
    await config.reserve();
    try {
      const results = await tavily('extract', { urls: [url], extract_depth: 'basic', format: 'text', timeout: 8 }, config);
      const entry = results.find((item) => canonicalUrl(item?.url) === url);
      extract = entry?.raw_content;
      title = entry?.title;
    } catch (error) {
      if (error.status === 429) throw error;
    }
  }
  return asSource({ url, category: 'lecture', title, extract, now: config.now });
}
