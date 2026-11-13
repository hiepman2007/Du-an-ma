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

test('without accounts, production still accepts the shared APP_TOKEN and rejects a wrong one', async (t) => {
  const keys = ['VERCEL', 'APP_TOKEN', 'SUPABASE_URL', 'STUDY_REQUIRE_AUTH'];
  const old = Object.fromEntries(keys.map((key) => [key, process.env[key]]));
  t.after(() => {
    for (const [key, value] of Object.entries(old)) {
      if (value == null) delete process.env[key];
      else process.env[key] = value;
    }
  });
  process.env.VERCEL = '1';
  process.env.APP_TOKEN = 'demo-token';
  delete process.env.SUPABASE_URL;
  delete process.env.STUDY_REQUIRE_AUTH;
  const remote = { remoteAddress: '203.0.113.9' };
  const wrong = response();
  await handler({ url: '/api/study/quiz', method: 'POST', headers: { 'x-app-token': 'nope' }, socket: remote, body: {} }, wrong);
  assert.equal(wrong.code, 401);
  const right = response();
  await handler({ url: '/api/study/quiz', method: 'POST', headers: { 'x-app-token': 'demo-token' }, socket: remote, body: { counts: {} } }, right);
  assert.equal(right.code, 400); // Qua lớp xác thực, tới kiểm tra yêu cầu quiz.
});
