import test from 'node:test';
import assert from 'node:assert/strict';
import { canonicalUrl, findStudySources, readStudyUrl, researchQueries } from './lib/research.js';

const now = new Date('2026-11-13T00:00:00.000Z');
const json = (data, status = 200) => new Response(JSON.stringify(data), { status });

test('curated sources cover DSA and additional subjects without model or network calls', async () => {
  for (const topic of ['DSA', 'Giải tích', 'Vật lý', 'Hóa học']) {
    const result = await findStudySources({ topic }, { key: '', now, fetcher: () => assert.fail() });
    assert.equal(result.mode, 'catalog');
    assert.ok(result.sources.some((source) => source.category === 'lecture' && source.extract));
    assert.ok(result.sources.some((source) => source.category === 'simulation'));
    assert.ok(result.sources.every((source) => source.retrieved_at === now.toISOString()));
    assert.ok(result.sources.filter((source) => source.category === 'exam').every((source) => !source.extract));
  }
  const unknown = await findStudySources({ topic: 'Quản trị dự án' }, { key: '' });
  assert.equal(unknown.mode, 'off');
  assert.deepEqual(unknown.sources, []);
  assert.equal(unknown.missing.length, 4);
});

test('research sends four scoped queries and normalizes the exact discovered URLs', async () => {
  const requests = [];
  const accepted = 'https://university.edu/notes?chapter=2';
  const exam = 'https://university.edu/exams/fall-2024';
  const fetcher = async (url, options) => {
    const body = JSON.parse(options.body);
    requests.push(body);
    if (url.endsWith('/extract')) {
      assert.deepEqual(body.urls, [accepted]);
      return json({ results: [
        { url: accepted, raw_content: 'Relevant lecture extract.' },
        { url: 'https://university.edu/different-page', raw_content: 'Invalid same-domain match.' },
      ] });
    }
    if (body.query.includes('past exams')) {
      return json({ results: [
        { url: 'https://coaching-site.com/practice', title: 'Past exams' },
        { url: exam, title: 'Fall exam' },
      ] });
    }
    return json({ results: [
      { url: `${accepted}&utm_source=test#heading`, title: 'Class notes', content: 'Snippet' },
      { url: 'http://127.0.0.1/class', title: 'Local site' },
    ] });
  };
  const result = await findStudySources({ topic: 'Economics', scope: 'Money' }, { key: 'test-key', now, fetcher });
  assert.equal(requests.length, 5);
  assert.ok(requests.slice(0, 4).every((body) => body.query.startsWith('Economics Money ')));
  assert.deepEqual(result.sources.map(({ url }) => url), [accepted, exam]);
  assert.equal(result.sources[0].extract, 'Relevant lecture extract.');
  assert.equal(result.sources[1].extract, '');
  assert.equal(result.mode, 'partial');
  assert.deepEqual(result.missing, ['practice', 'simulation']);
});

test('known catalog remains available on search quota error and direct URL import is link-only without extraction', async () => {
  const result = await findStudySources({ topic: 'DSA' }, {
    key: 'test-key', now,
    reserve: () => { throw Object.assign(new Error('quota'), { status: 429 }); },
    fetcher: () => assert.fail(),
  });
  assert.equal(result.mode, 'partial');
  assert.ok(result.sources.length > 0);
  const source = await readStudyUrl('https://university.edu/notes#start', { key: '', now });
  assert.equal(source.url, 'https://university.edu/notes');
  assert.equal(source.extract, '');
  assert.equal(source.id, (await readStudyUrl('https://university.edu/notes?utm_source=test', { key: '', now })).id);
  await assert.rejects(readStudyUrl('file:///etc/passwd'), { status: 400 });
  assert.equal(canonicalUrl('http://0x7f000001/path'), '');
  assert.equal(canonicalUrl('https://user:pass@university.edu/path'), '');
  assert.ok(researchQueries('DSA https://university.edu/x admin@example.com').every(({ query }) => !query.includes('.edu') && !query.includes('@')));
});
