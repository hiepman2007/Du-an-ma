import test from 'node:test';
import assert from 'node:assert/strict';
import { quizPlan } from './lib/study.js';
import quizHandler from './lib/routes/study/quiz.js';

test('quiz plan caps at 15 questions, a passage counts as 3, unknown options fall back', () => {
  const plan = quizPlan({ counts: { mcq: 10, passage: 3, true_false: 'x' }, difficulty: 'impossible' });
  assert.deepEqual(plan.counts, { mcq: 10, passage: 1 });
  assert.equal(plan.total, 13);
  assert.equal(plan.difficulty, 'medium');
  assert.throws(() => quizPlan({ counts: {} }), /ít nhất một câu/);
});

test('quiz endpoint keeps passages with their questions and trims extra questions', async (t) => {
  const env = { STUDY_REQUIRE_AUTH: undefined, SUPABASE_URL: undefined, VERCEL: undefined, NODE_ENV: undefined,
    APP_TOKEN: 'fixture', AI_PROVIDER: 'gemini', GEMINI_API_KEY: 'test' };
  const old = Object.fromEntries(Object.keys(env).map((key) => [key, process.env[key]]));
  const apply = (values) => {
    for (const [key, value] of Object.entries(values)) {
      if (value == null) delete process.env[key];
      else process.env[key] = value;
    }
  };
  apply(env);
  t.after(() => apply(old));

  const source = { id: 'web-a', title: 'Bài giảng', url: 'https://university.edu/queue', extract: 'A queue processes items in the order they arrive.' };
  const mcq = (n) => ({ type: 'mcq', topic: 'Hàng đợi', body: `Câu ${n}`, options: ['A', 'B', 'C', 'D'], answer_index: 0, explanation: 'Vì FIFO.', source_id: 'web-a' });
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    const input = JSON.parse(options.body);
    const types = input.response_format.schema.properties.blocks.items.properties.type.enum;
    assert.deepEqual(types, ['text_section', 'mcq']);
    const prompt = input.input.at(-1).text;
    assert.ok(prompt.includes('1 đoạn tình huống'));
    assert.ok(prompt.includes('Khó'));
    const blocks = [{ type: 'text_section', body: 'Một hàng đợi in ấn...', source_id: 'web-a' }, mcq(1), mcq(2), mcq(3), mcq(4), mcq(5)];
    return Response.json({ steps: [{ type: 'model_output', content: [{ type: 'text', text: JSON.stringify({ title: 'Quiz hàng đợi', blocks }) }] }] });
  });
  const response = { code: 0, body: undefined, setHeader() {}, status(code) { this.code = code; return this; }, json(value) { this.body = value; } };
  await quizHandler({ url: '/api/study/quiz', method: 'POST', socket: { remoteAddress: '127.0.0.1' }, headers: { 'x-app-token': 'fixture' },
    body: { topic: 'Hàng đợi', counts: { mcq: 1, passage: 1 }, difficulty: 'hard', sources: [source] } }, response);
  assert.equal(response.code, 200);
  assert.equal(response.body.questions, 4);
  assert.deepEqual(response.body.blocks.map((b) => b.type), ['text_section', 'mcq', 'mcq', 'mcq', 'mcq']);
  assert.equal(response.body.blocks[1].explanation, 'Vì FIFO.');
});
