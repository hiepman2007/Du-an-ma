import test from 'node:test';
import assert from 'node:assert/strict';
import { cleanBlocks, safeExpression } from './lib/validate.js';

test('safeExpression chan bieu thuc la', () => {
  assert.equal(safeExpression('U/R', new Set(['U', 'R'])), true);
  assert.equal(safeExpression('a*x^2+b*x+c', new Set(['x', 'a', 'b', 'c'])), true);
  assert.equal(safeExpression('process.exit()', new Set(['x'])), false);
  assert.equal(safeExpression('U/R; alert(1)', new Set(['U', 'R'])), false);
  assert.equal(safeExpression('sqrt(x)', new Set(['x'])), true);
});

test('cleanBlocks bo khoi sai va URL la', () => {
  const base = { topic: 't', title: null, body: null, options: [], answer_index: null, answer_bool: null, answers: [], pairs: [], items: [], cards: [], lab: null, graph: null, explanation: null, source_quote: null, source_page: null, source_url: null };
  const blocks = [
    { ...base, type: 'text_section', body: 'Xin chao' },
    { ...base, type: 'mcq', body: 'Q', options: ['a', 'b', 'c', 'd'], answer_index: 9 },          // dap an ngoai pham vi -> bo
    { ...base, type: 'mcq', body: 'Q', options: ['a', 'b'], answer_index: 1, source_url: 'https://bia.example/x' }, // URL khong co trong nguon -> null
    { ...base, type: 'khong_co_loai_nay' },
    { ...base, type: 'formula_lab', lab: { formula: 'U/R', result_label: 'I', result_unit: 'A', variables: [{ name: 'U', label: 'U', unit: 'V', min: 0, max: 24, step: 1, default: 12 }, { name: 'R', label: 'R', unit: 'ohm', min: 1, max: 10, step: 1, default: 4 }] } },
    { ...base, type: 'formula_lab', lab: { formula: 'require("fs")', result_label: 'I', result_unit: 'A', variables: [{ name: 'U', label: 'U', unit: 'V', min: 0, max: 24, step: 1, default: 12 }] } },
  ];
  const out = cleanBlocks(blocks, { allowedUrls: new Set(['https://ok.example/a']) });
  assert.equal(out.length, 3);
  assert.equal(out[1].source_url, null);
  assert.equal(out[2].type, 'formula_lab');
});
