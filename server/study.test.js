import test from 'node:test';
import assert from 'node:assert/strict';
import { studyMaterial, validateDsaSimulation, validateStudyBlocks, validateStudyOutline } from './lib/study.js';
import researchHandler from './lib/routes/study/research.js';
import sourceHandler from './lib/routes/study/source.js';
import outlineHandler from './lib/routes/study/outline.js';
import lessonHandler from './lib/routes/study/lesson.js';
import artifactHandler from './lib/routes/study/artifact.js';
import askHandler from './lib/routes/study/ask.js';

test('grounding accepts readable evidence, matches exact quotes, and clears unrelated citations', () => {
  const { evidence, parts } = studyMaterial({
    sources: [
      { id: 'web-a', title: 'Bài giảng', url: 'https://university.edu/lesson', extract: 'A queue processes items in the order they arrive.' },
      { id: 'web-b', title: 'Đề thi', url: 'https://university.edu/exam', snippet: 'Source link only' },
    ],
    texts: [{ id: 'text-a', title: 'Ghi chú', text: 'Mảng lưu các phần tử theo chỉ số.' }],
    files: [{ id: 'file-a', name: 'Đề cương', mimeType: 'application/pdf', fileId: 'provider-id', pages: [{ page: 2, text: 'Đồ thị có đỉnh và cạnh.' }] }],
  });
  assert.deepEqual([...evidence.keys()], ['file-a', 'web-a', 'text-a']);
  assert.ok(parts.every(({ text }) => !text?.includes('Source link only')));
  const [web, wrong, pdf, text, invented] = validateStudyBlocks([
    { source_id: 'web-a', source_quote: 'processes items in the order', source_url: 'https://university.edu/fake' },
    { source_id: 'web-a', source_quote: 'never appears', source_page: 4 },
    { source_id: 'file-a', source_quote: 'Đồ thị có đỉnh và cạnh.', source_page: 2 },
    { source_id: 'text-a', source_quote: 'Mảng lưu các phần tử theo chỉ số.' },
    { source_id: 'web-b', source_quote: 'Source link only', source_url: 'https://university.edu/exam' },
  ].map((block) => ({ ...block, type: 'text_section', body: 'Nội dung' })), evidence, ['text_section']);
  assert.equal(web.source_url, 'https://university.edu/lesson');
  assert.equal(web.source_quote, 'processes items in the order');
  assert.equal(wrong.source_quote, null);
  assert.equal(wrong.source_page, null);
  assert.equal(pdf.source_page, 2);
  assert.equal(text.source_id, 'text-a');
  assert.equal(invented.source_id, null);
  assert.equal(invented.source_url, null);
});

test('outline drops duplicate lessons, future dependencies and missing source IDs', () => {
  const lessons = [
    { id: 'a', title: 'Mảng', minutes: 42, prerequisites: ['b'], source_ids: ['allowed', 'made-up'] },
    { id: 'a', title: 'Bị trùng' },
    { id: 'b', title: 'Đồ thị', phase: 'Mở rộng', prerequisites: ['a', 'a', 'b'] },
  ];
  const result = validateStudyOutline({ lessons }, new Map([['allowed', {}]]), { topic: 'DSA', minutes_per_day: 20 });
  assert.deepEqual(result.lessons.map(({ id }) => id), ['a', 'b']);
  assert.equal(result.lessons[0].minutes, 20);
  assert.deepEqual(result.lessons[0].source_ids, ['allowed']);
  assert.deepEqual(result.lessons[0].prerequisites, []);
  assert.deepEqual(result.lessons[1].prerequisites, ['a']);
});

test('DSA input is bounded, sorted and only refers to known graph nodes', () => {
  assert.deepEqual(validateDsaSimulation({ algorithm: 'binary_search', values: [1, 3, 5], target: 4 }), {
    algorithm: 'binary_search', values: [1, 3, 5], target: 4,
  });
  assert.equal(validateDsaSimulation({ algorithm: 'binary_search', values: [3, 1], target: 4 }), null);
  assert.equal(validateDsaSimulation({ algorithm: 'bfs', nodes: ['A', 'B'], start: 'C', edges: [] }), null);
  assert.equal(validateDsaSimulation({ algorithm: 'dfs', nodes: ['A', 'B'], start: 'A', edges: [{ from: 'A', to: 'C' }] }), null);
  assert.ok(validateDsaSimulation({ algorithm: 'dfs', nodes: ['A', 'B'], start: 'A', edges: [{ from: 'A', to: 'B' }] }));
});

test('study endpoints assemble a course in two model calls and ground Studio and chat in selected evidence', async (t) => {
  const env = {
    STUDY_REQUIRE_AUTH: undefined, SUPABASE_URL: undefined, VERCEL: undefined, NODE_ENV: undefined,
    APP_TOKEN: 'fixture', AI_PROVIDER: 'gemini', GEMINI_API_KEY: 'test', TAVILY_API_KEY: undefined,
  };
  const old = Object.fromEntries(Object.keys(env).map((key) => [key, process.env[key]]));
  const applyEnv = (values) => {
    for (const [key, value] of Object.entries(values)) {
      if (value == null) delete process.env[key];
      else process.env[key] = value;
    }
  };
  applyEnv(env);
  t.after(() => applyEnv(old));

  let modelCalls = 0;
  let failOnce = true;
  let source;
  const lecture = () => ({ type: 'text_section', body: 'Mảng truy cập theo chỉ số.', source_id: source.id,
    source_quote: 'Array-based lists support constant-time indexed access.' });
  const checkpoint = () => ({ type: 'true_false', body: 'Có thể truy cập mảng bằng chỉ số.', answer_bool: true, source_id: source.id });
  const simulation = () => ({ type: 'dsa_sim', dsa_sim: { algorithm: 'binary_search', values: [0, 3, 5], target: 3 } });
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    assert.equal(url, 'https://generativelanguage.googleapis.com/v1beta/interactions');
    const input = JSON.parse(options.body);
    assert.equal(input.tools, undefined);
    assert.ok(input.input.some((part) => part.type === 'text' && part.text.includes(`[${source.id}]`)));
    const shape = input.response_format.schema.properties;
    modelCalls++;
    let output;
    if (shape.lessons) {
      output = { title: 'DSA', lessons: [{ id: 'a', title: 'Mảng', source_ids: [source.id] }, { id: 'b', title: 'Đồ thị', prerequisites: ['a'] }] };
    } else if (shape.blocks.items.properties.type.enum.includes('dsa_sim')) {
      if (failOnce) {
        failOnce = false;
        return new Response('quota', { status: 429 });
      }
      output = { title: 'Mảng', blocks: [lecture(), simulation(), checkpoint()] };
    } else {
      output = { title: 'Tóm tắt', blocks: [lecture()] };
    }
    return Response.json({ steps: [{ type: 'model_output', content: [{ type: 'text', text: JSON.stringify(output) }] }] });
  });
  async function post(handler, path, body) {
    const response = {
      code: 0, body: undefined, setHeader() {},
      status(code) { this.code = code; return this; }, json(value) { this.body = value; },
    };
    await handler({ url: `/api/study/${path}`, method: 'POST', socket: { remoteAddress: '127.0.0.1' },
      headers: { 'x-app-token': 'fixture' }, body }, response);
    return response;
  }

  const research = await post(researchHandler, 'research', { topic: 'DSA' });
  assert.equal(research.code, 200);
  assert.equal(research.body.mode, 'catalog');
  source = research.body.sources.find(({ title }) => title.includes('Array-Based Lists'));
  const imported = await post(sourceHandler, 'source', { url: `${source.url}?utm_source=demo` });
  assert.equal(imported.code, 200);
  assert.equal(imported.body.source.id, source.id);
  assert.equal(modelCalls, 0);

  const material = { sources: [source] };
  const outline = await post(outlineHandler, 'outline', { brief: { topic: 'DSA', minutes_per_day: 15 }, ...material });
  assert.equal(outline.code, 200);
  assert.equal(outline.body.lessons[1].prerequisites[0], 'a');
  const lessonRequest = { course: outline.body, lessonId: 'a', ...material };
  const exhausted = await post(lessonHandler, 'lesson', lessonRequest);
  assert.equal(exhausted.code, 429);
  const lesson = await post(lessonHandler, 'lesson', lessonRequest);
  assert.equal(lesson.code, 200);
  assert.equal(lesson.body.blocks[1].dsa_sim.algorithm, 'binary_search');
  assert.equal(lesson.body.blocks[2].answer_bool, true);
  assert.equal(modelCalls, 3); // Two successful calls, plus one simulated quota failure.

  const summary = await post(artifactHandler, 'artifact', { kind: 'summary', topic: 'Mảng', ...material });
  assert.equal(summary.code, 200);
  assert.equal(summary.body.blocks[0].source_url, source.url);
  const answer = await post(askHandler, 'ask', { question: 'Mảng hoạt động thế nào?', ...material });
  assert.equal(answer.code, 200);
  assert.deepEqual(answer.body.source_ids, [source.id]);
});

test('chat học tập nhận khối mô phỏng tự dựng và ảnh minh họa', () => {
  const types = ['text_section', 'image_card', 'custom_sim'];
  const blocks = validateStudyBlocks([
    { type: 'text_section', topic: 'Quang hợp', body: 'Cây dùng ánh sáng để tạo glucose.' },
    { type: 'image_card', topic: 'Quang hợp', image_query: 'chloroplast diagram', body: 'Lục lạp' },
    { type: 'custom_sim', topic: 'Quang hợp', sim_prompt: 'Lá cây hấp thụ ánh sáng, thanh trượt cường độ ánh sáng và CO2, đếm bọt O2.' },
    { type: 'custom_sim', topic: 'Quang hợp', sim_prompt: '' },
  ], new Map(), types);
  assert.deepEqual(blocks.map((b) => b.type), ['text_section', 'image_card', 'custom_sim']);
});
