import test from 'node:test';
import assert from 'node:assert/strict';
import { cleanBlocks, sanitizeSimulationHtml } from './lib/validate.js';
import { adaptSchema } from './lib/providers/gemini.js';
import { lessonSchema } from './lib/schemas.js';

const v = (name, min = 0, max = 10) => ({ name, label: name, unit: '', min, max, step: 1, default: min });

test('reaction_lab: bo phan ung tham chieu chat khong ton tai, sua mau sai', () => {
  const blk = {
    type: 'reaction_lab', topic: 'Trung hoa',
    reaction: {
      setup: 'Coc thuy tinh', no_reaction_text: 'Khong co hien tuong', safety: null,
      reagents: [
        { id: 'hcl', name: 'Axit clohidric', formula: 'HCl', color: '#ffffff', state: 'solution' },
        { id: 'naoh', name: 'Natri hidroxit', formula: 'NaOH', color: 'trang', state: 'solution' },
      ],
      reactions: [
        { reagents: ['hcl', 'naoh'], equation: 'HCl + NaOH -> NaCl + H2O', observation: 'Toa nhiet', color: '#f0f0f0', gas: false, precipitate: false, precipitate_color: null, heat: 'exo', min_temp: null, explanation: 'x' },
        { reagents: ['hcl', 'khong_co'], equation: 'bia', observation: '', color: '#000000', gas: false, precipitate: false, precipitate_color: null, heat: 'none', min_temp: null, explanation: '' },
      ],
    },
  };
  const [out] = cleanBlocks([blk]);
  assert.equal(out.reaction.reactions.length, 1);
  assert.equal(out.reaction.reagents[1].color, '#e8f1ff');
});

test('motion_sim can dung ten bien; chem_formula chan chuoi la', () => {
  const ok = { type: 'motion_sim', topic: 't', motion: { kind: 'projectile', variables: [v('v0', 1, 50), v('angle', 0, 90), v('g', 1, 20)] } };
  const bad = { type: 'motion_sim', topic: 't', motion: { kind: 'projectile', variables: [v('speed', 1, 50)] } };
  const chem = { type: 'chem_formula', topic: 't', chem: { formula: 'Ca(OH)2', name: 'Canxi hidroxit' } };
  const chemBad = { type: 'chem_formula', topic: 't', chem: { formula: '<script>', name: 'x' } };
  const out = cleanBlocks([ok, bad, chem, chemBad]);
  assert.deepEqual(out.map((b) => b.type), ['motion_sim', 'chem_formula']);
});

test('sanitizeSimulationHtml chan tai nguyen ngoai va boc CSP', () => {
  assert.equal(sanitizeSimulationHtml('<script src="https://cdn.x/y.js"></script>' + 'a'.repeat(60)), null);
  assert.equal(sanitizeSimulationHtml('<script>fetch("https://evil")</script>' + 'a'.repeat(60)), null);
  const ok = sanitizeSimulationHtml('<canvas id="c"></canvas><script>const c=document.getElementById("c");</script>' + ' '.repeat(10));
  assert.ok(ok.includes("default-src 'none'"));
  assert.ok(ok.includes('<canvas'));
});

test('schema bai hoc cho Gemini khong con anyOf', () => {
  assert.equal(JSON.stringify(adaptSchema(lessonSchema)).includes('anyOf'), false);
});

test('phenomenon_sim: chi nhan canh trong danh muc, bo bien la, kep gia tri mac dinh', () => {
  const [blk] = cleanBlocks([{
    type: 'phenomenon_sim', topic: 'Khuc xa',
    phenomenon: { scene: 'refraction', option: 'xyz', challenges: ['Thu tang goc toi', ''],
      variables: [{ ...v('angle', 0, 89), default: 120 }, v('bien_la')] },
  }]);
  assert.equal(blk.phenomenon.scene, 'refraction');
  assert.equal(blk.phenomenon.option, null);
  assert.deepEqual(blk.phenomenon.variables.map((x) => x.name), ['angle']);
  assert.equal(blk.phenomenon.variables[0].default, 89);
  assert.deepEqual(blk.phenomenon.challenges, ['Thu tang goc toi']);
  const [circuit] = cleanBlocks([{ type: 'phenomenon_sim', topic: 'Ohm', phenomenon: { scene: 'circuit', option: 'parallel', variables: [], challenges: [] } }]);
  assert.equal(circuit.phenomenon.option, 'parallel');
  assert.equal(cleanBlocks([{ type: 'phenomenon_sim', topic: 'x', phenomenon: { scene: 'rocket', option: null, variables: [], challenges: [] } }]).length, 0);
});
