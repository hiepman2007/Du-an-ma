import test from 'node:test';
import assert from 'node:assert/strict';
import { sanitizeSimulationHtml, unwrapSimulationHtml } from './lib/validate.js';
import simulationHandler from './api/simulation.js';

const page = '<body><h1>Con lắc</h1><input type="range" id="l"><canvas id="c"></canvas><script>let t=0;</script></body>';

test('canvas unwraps the CSP wrapper so a revision is not wrapped twice', () => {
  const wrapped = sanitizeSimulationHtml(page);
  assert.ok(wrapped.includes('Content-Security-Policy'));
  const raw = unwrapSimulationHtml(wrapped);
  assert.ok(!raw.includes('Content-Security-Policy'));
  assert.ok(!raw.includes('viewport'));
  const again = sanitizeSimulationHtml(raw);
  assert.equal(again.match(/Content-Security-Policy/g).length, 1);
});

test('simulation endpoint revises the previous page and rejects pages that load external resources', async (t) => {
  const env = { VERCEL: undefined, NODE_ENV: undefined, APP_TOKEN: 'fixture', AI_PROVIDER: 'gemini', GEMINI_API_KEY: 'test',
    STUDY_REQUIRE_AUTH: undefined, SUPABASE_URL: undefined };
  const old = Object.fromEntries(Object.keys(env).map((key) => [key, process.env[key]]));
  const apply = (values) => {
    for (const [key, value] of Object.entries(values)) {
      if (value == null) delete process.env[key];
      else process.env[key] = value;
    }
  };
  apply(env);
  t.after(() => apply(old));

  const prompts = [];
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    const input = JSON.parse(options.body);
    prompts.push(input.input.at(-1).text);
    calls++;
    const html = calls === 1 ? '<script src="https://cdn.example.com/x.js"></script>' + page : page.replace('Con lắc', 'Con lắc có ma sát');
    const output = { title: 'Con lắc', instructions: 'Đã thêm ma sát.', html };
    return Response.json({ steps: [{ type: 'model_output', content: [{ type: 'text', text: JSON.stringify(output) }] }] });
  });
  const response = { code: 0, body: undefined, setHeader() {}, status(code) { this.code = code; return this; }, json(value) { this.body = value; } };
  await simulationHandler({ url: '/api/simulation', method: 'POST', socket: { remoteAddress: '127.0.0.1' }, headers: { 'x-app-token': 'fixture' },
    body: { simPrompt: 'Thêm ma sát', lessonTitle: 'Dao động', previousHtml: sanitizeSimulationHtml(page) } }, response);
  assert.equal(response.code, 200);
  assert.equal(calls, 2); // Lần đầu có tài nguyên ngoài nên bị từ chối và thử lại.
  assert.ok(prompts[0].includes('Yeu cau chinh sua cua hoc sinh: Thêm ma sát'));
  assert.ok(prompts[0].includes('<h1>Con lắc</h1>'));
  assert.ok(!prompts[0].includes('Content-Security-Policy'));
  assert.ok(response.body.html.includes('Con lắc có ma sát'));
});
