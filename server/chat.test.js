import test from 'node:test';
import assert from 'node:assert/strict';
import { cleanBlocks } from './lib/validate.js';
import { askSystem, exercisesSystem } from './lib/prompts.js';
import { lessonSchema } from './lib/schemas.js';
import { repairLatex } from './lib/ai.js';

test('code_demo: hop le khi co source <= 4000 ky tu', () => {
  const ok = { type: 'code_demo', topic: 'Vong lap', code: { language: 'python', source: 'for i in range(3):\n    print(i)', output: '0\n1\n2' } };
  const tooLong = { type: 'code_demo', topic: 'x', code: { language: 'python', source: 'x'.repeat(5000), output: '' } };
  const empty = { type: 'code_demo', topic: 'x', code: null };
  assert.deepEqual(cleanBlocks([ok, tooLong, empty]).map((b) => b.type), ['code_demo']);
});

test('prompt gia su va bo de dung LaTeX, nhac danh muc khoi', () => {
  const a = askSystem('student');
  assert.ok(a.includes('code_demo') && a.includes('$...$'));
  assert.ok(exercisesSystem('pupil', 'hard').includes('KHÓ'));
  assert.ok(lessonSchema.properties.blocks.items.properties.code);
});

test('repairLatex sua ky tu dieu khien trong cong thuc', () => {
  const BS = '\\';
  const TAB = '\t', FF = '\f', NL = '\n';
  // Gia lap JSON bi parse sai: "\text" -> tab + "ext", "\frac" -> form feed + "rac", "\neq" -> xuong dong + "eq"
  const broken = {
    a: '$R = 4' + TAB + 'ext{ }' + BS + 'Omega$',
    b: '$' + FF + 'rac{U}{R}$ va $x ' + NL + 'eq 0$',
    c: 'Dong 1' + NL + 'Dong 2',
    d: { source: 'a' + TAB + 'b' },
  };
  const fixed = repairLatex(broken);
  assert.equal(fixed.a, '$R = 4' + BS + 'text{ }' + BS + 'Omega$');
  assert.equal(fixed.b, '$' + BS + 'frac{U}{R}$ va $x ' + BS + 'neq 0$');
  assert.equal(fixed.c, 'Dong 1' + NL + 'Dong 2'); // xuong dong that ngoai cong thuc giu nguyen
  assert.equal(fixed.d.source, 'a' + TAB + 'b'); // code giu nguyen
});
