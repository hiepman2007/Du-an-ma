// Kiem tra/lam sach khoi truoc khi gui ve app: bo khoi sai, chan bieu thuc la, chi giu URL do cong cu tim kiem tra ve.
import { BLOCK_TYPES, MOTION_KINDS } from './schemas.js';

const EXPR_OK = /^[0-9a-zA-Z_+\-*/^().,\s]+$/;
const ALLOWED_FUNCS = new Set(['sin', 'cos', 'tan', 'sqrt', 'abs', 'ln', 'log', 'exp', 'pi', 'e']);
const HEX = /^#[0-9a-fA-F]{6}$/;
const FORMULA_OK = /^[A-Za-z0-9()[\]·.+\-]{1,40}$/;

// Bien bat buoc cho tung kieu mo phong chuyen dong (app dua vao ten bien de mo phong).
export const MOTION_VARS = {
  projectile: ['v0', 'angle', 'g'],
  free_fall: ['h', 'g'],
  pendulum: ['L', 'theta0', 'g'],
};

export function safeExpression(expr, names) {
  if (typeof expr !== 'string' || !expr || expr.length > 120 || !EXPR_OK.test(expr)) return false;
  const idents = expr.match(/[a-zA-Z_][a-zA-Z0-9_]*/g) || [];
  return idents.every((id) => names.has(id) || ALLOWED_FUNCS.has(id));
}

const goodVars = (vs) => Array.isArray(vs) && vs.every((v) => v.min < v.max && v.step > 0);

function cleanReaction(r) {
  if (!r || !Array.isArray(r.reagents) || r.reagents.length < 2 || r.reagents.length > 8) return null;
  const ids = new Set(r.reagents.map((x) => x.id));
  const reagents = r.reagents.map((x) => ({ ...x, color: HEX.test(x.color) ? x.color : '#e8f1ff' }));
  const reactions = (r.reactions || [])
    .filter((x) => x.reagents?.length >= 1 && x.reagents.every((id) => ids.has(id)) && x.equation)
    .map((x) => ({
      ...x,
      color: HEX.test(x.color) ? x.color : '#e8f1ff',
      precipitate_color: x.precipitate_color && HEX.test(x.precipitate_color) ? x.precipitate_color : null,
    }));
  if (!reactions.length) return null;
  return { ...r, reagents, reactions };
}

export function cleanBlocks(blocks, { allowedUrls } = {}) {
  const out = [];
  for (const b of blocks || []) {
    if (!BLOCK_TYPES.includes(b.type)) continue;
    const blk = { ...b };
    if (blk.source_url && allowedUrls && !allowedUrls.has(blk.source_url)) blk.source_url = null;
    let ok = true;
    switch (blk.type) {
      case 'text_section': ok = !!blk.body; break;
      case 'mcq': ok = !!blk.body && blk.options?.length >= 2 && Number.isInteger(blk.answer_index) && blk.answer_index >= 0 && blk.answer_index < blk.options.length; break;
      case 'true_false': ok = !!blk.body && typeof blk.answer_bool === 'boolean'; break;
      case 'fill_blank': ok = !!blk.body && blk.answers?.length > 0; break;
      case 'matching': ok = blk.pairs?.length >= 2; break;
      case 'ordering': ok = blk.items?.length >= 2; break;
      case 'flashcards': ok = blk.cards?.length >= 1; break;
      case 'step_solver': ok = !!blk.body && blk.steps?.length >= 2; break;
      case 'concept_map': {
        const ids = new Set((blk.nodes || []).map((n) => n.id));
        blk.edges = (blk.edges || []).filter((e) => ids.has(e.from) && ids.has(e.to));
        ok = ids.size >= 3 && ids.size <= 14;
        break;
      }
      case 'image_card': ok = !!blk.image_query; break; // anh that duoc gan o server (resolveImages)
      case 'custom_sim': ok = !!blk.sim_prompt; break;  // HTML sinh khi hoc sinh bam
      case 'code_demo': ok = !!blk.code && typeof blk.code.source === 'string' && blk.code.source.length > 0 && blk.code.source.length <= 4000; break;
      case 'formula_lab': {
        const names = new Set((blk.lab?.variables || []).map((v) => v.name));
        ok = !!blk.lab && names.size > 0 && safeExpression(blk.lab.formula, names) && goodVars(blk.lab.variables);
        break;
      }
      case 'function_graph': {
        const g = blk.graph;
        const names = new Set(['x', ...(g?.params || []).map((v) => v.name)]);
        ok = !!g && safeExpression(g.expression, names) && g.x_min < g.x_max && goodVars(g.params || []);
        if (ok) g.extra_expressions = (g.extra_expressions || []).filter((e) => safeExpression(e, names)).slice(0, 2);
        break;
      }
      case 'reaction_lab': blk.reaction = cleanReaction(blk.reaction); ok = !!blk.reaction; break;
      case 'chem_formula': ok = !!blk.chem && FORMULA_OK.test(blk.chem.formula || ''); break;
      case 'motion_sim': {
        const m = blk.motion;
        const names = new Set((m?.variables || []).map((v) => v.name));
        ok = !!m && MOTION_KINDS.includes(m.kind) && MOTION_VARS[m.kind].every((n) => names.has(n)) && goodVars(m.variables);
        break;
      }
    }
    if (ok) out.push(blk);
  }
  return out;
}

// --- Mo phong tuy bien (HTML do AI viet) ---
const FORBIDDEN = [
  /<script[^>]+src\s*=/i, /<link[^>]+href\s*=\s*["']?https?:/i, /<iframe/i, /<object/i, /<embed/i,
  /\bfetch\s*\(/i, /XMLHttpRequest/i, /WebSocket/i, /EventSource/i, /\bimport\s*\(/i, /sendBeacon/i,
  /localStorage/i, /sessionStorage/i, /indexedDB/i, /document\.cookie/i, /window\.open/i,
  /(src|href)\s*=\s*["']?\s*(https?:|\/\/)/i, /url\(\s*["']?\s*(https?:|\/\/)/i, /@import/i,
];

/** Tra ve HTML da boc CSP chan moi ket noi ngoai, hoac null neu vi pham. */
export function sanitizeSimulationHtml(html) {
  if (typeof html !== 'string' || html.length < 50 || html.length > 30000) return null;
  if (FORBIDDEN.some((re) => re.test(html))) return null;
  const csp = `<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src data:">`;
  const viewport = '<meta name="viewport" content="width=device-width, initial-scale=1">';
  const body = html.replace(/<!doctype[^>]*>/i, '').replace(/<\/?html[^>]*>/gi, '').replace(/<head>|<\/head>/gi, '');
  return `<!doctype html><html><head><meta charset="utf-8">${csp}${viewport}</head>${body.includes('<body') ? body : `<body>${body}</body>`}</html>`;
}
