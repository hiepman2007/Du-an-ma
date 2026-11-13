import test from 'node:test';
import assert from 'node:assert/strict';
import { adaptSchema } from './lib/providers/gemini.js';
import { lessonSchema } from './lib/schemas.js';
import { pickSources, citationDomain } from './api/sources/search.js';
import { modelFor, providerName } from './lib/ai.js';

test('adaptSchema bo anyOf [object, null] cho Gemini', () => {
  const out = adaptSchema(lessonSchema);
  const block = out.properties.blocks.items;
  assert.deepEqual(block.properties.lab.type, ['object', 'null']);
  assert.equal(block.properties.lab.anyOf, undefined);
  assert.ok(block.properties.lab.properties.variables);
  assert.equal(JSON.stringify(out).includes('anyOf'), false);
});

test('pickSources chi giu nguon do cong cu tim kiem tra ve (ca link chuyen huong)', () => {
  const citations = [
    { url: 'https://vertexaisearch.cloud.google.com/grounding-api-redirect/abc', title: 'khanacademy.org' },
    { url: 'https://example.com/blog', title: 'Blog' },
  ];
  assert.equal(citationDomain(citations[0]), 'khanacademy.org');
  const listed = [
    { title: 'Khan', url: 'https://www.khanacademy.org/science/ohm', snippet: 's' },
    { title: 'Bia', url: 'https://fake-site.test/x', snippet: 'bia' },
  ];
  const out = pickSources(listed, citations);
  assert.equal(out.some((s) => s.url.includes('fake-site')), false);
  assert.equal(out[0].domain, 'khanacademy.org');
  assert.equal(out[0].trust, 'trusted');
  assert.ok(out.some((s) => s.domain === 'example.com' && s.trust === 'check'));
});

test('chon nha cung cap va model mac dinh', () => {
  const saved = { ...process.env };
  process.env.AI_PROVIDER = 'gemini';
  delete process.env.MODEL_LESSON;
  assert.equal(providerName(), 'gemini');
  assert.equal(modelFor('lesson'), 'gemini-3.5-flash-lite');
  process.env.AI_PROVIDER = 'openai';
  assert.equal(modelFor('lesson'), 'gpt-6-luna');
  process.env = saved;
});
