import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync } from 'node:fs';
import handler, { studyAction } from './api/study/[action].js';

const response = () => ({ code: 0, body: undefined, setHeader() {}, status(code) { this.code = code; return this; }, json(value) { this.body = value; } });

test('one study function routes by the last path segment or the Vercel query', async () => {
  assert.equal(studyAction({ url: '/api/study/quiz?x=1' }), 'quiz');
  assert.equal(studyAction({ url: '/api/study/whatever', query: { action: 'outline' } }), 'outline');
  const missing = response();
  await handler({ url: '/api/study/__proto__', method: 'POST', headers: {}, socket: { remoteAddress: '127.0.0.1' } }, missing);
  assert.equal(missing.code, 404);
});

test('deployment stays within the Vercel Hobby limit of 12 functions', () => {
  const count = (dir) => readdirSync(dir, { withFileTypes: true })
    .reduce((n, e) => n + (e.isDirectory() ? count(`${dir}/${e.name}`) : e.name.endsWith('.js') ? 1 : 0), 0);
  assert.ok(count('api') <= 12, `api/ has ${count('api')} functions`);
});
