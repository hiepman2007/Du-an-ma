// Lop trung gian chon nha cung cap AI: AI_PROVIDER=openai | gemini (mac dinh: gemini neu chi co GEMINI_API_KEY).
import { fail } from './http.js';
import { consumeStudyQuota, currentStudyAccount, recordStudyUsage } from './account.js';
import * as openai from './providers/openai.js';
import * as gemini from './providers/gemini.js';

export function providerName() {
  const p = (process.env.AI_PROVIDER || '').toLowerCase();
  if (p === 'openai' || p === 'gemini') return p;
  return process.env.OPENAI_API_KEY ? 'openai' : 'gemini';
}

function provider() {
  return providerName() === 'openai' ? openai : gemini;
}

const DEFAULT_MODELS = {
  openai: { outline: 'gpt-6-luna', lesson: 'gpt-6-luna', small: 'gpt-6-luna' },
  gemini: { outline: 'gemini-3.5-flash-lite', lesson: 'gemini-3.5-flash-lite', small: 'gemini-3.5-flash-lite' },
};

/**
 * Model theo buoc: MODEL_OUTLINE / MODEL_LESSON / MODEL_SMALL (cho nha cung cap dang dung), de trong thi dung mac dinh.
 * Neu ten model khong khop nha cung cap (vd "gpt-..." khi dang dung Gemini) thi bo qua, dung mac dinh,
 * de doi AI_PROVIDER khong lam hong server.
 */
export function modelFor(kind) {
  const p = providerName();
  const env = { outline: process.env.MODEL_OUTLINE, lesson: process.env.MODEL_LESSON, small: process.env.MODEL_SMALL }[kind];
  const matches = env && (p === 'gemini' ? env.startsWith('gemini') : !env.startsWith('gemini'));
  return matches ? env : DEFAULT_MODELS[p][kind];
}

// Gia USD / 1 trieu token (input, cached input, output) - trang gia OpenAI va Google ngay 13/11/2026.
const PRICES = {
  'gpt-6-luna': [0.1, 0.01, 0.5],
  'gpt-6.1-terra': [1.0, 0.05, 5.0],
  'gpt-6.1-sol': [2.0, 0.1, 10.0],
  'gemini-3.5-flash-lite': [0.3, 0.03, 2.5],
  'gemini-3.8-flash': [0.75, 0.075, 3.75],
  'gemini-4-hydrogen': [1.5, 0.075, 7.5],
};

export const usageTotals = { provider: null, calls: 0, inputTokens: 0, cachedTokens: 0, outputTokens: 0, usd: 0, perStep: {} };

function record(step, model, u) {
  const p = PRICES[model] || [0, 0, 0];
  const usd = ((u.input - u.cached) * p[0] + u.cached * p[1] + u.output * p[2]) / 1e6;
  usageTotals.provider = providerName();
  usageTotals.calls += 1;
  usageTotals.inputTokens += u.input;
  usageTotals.cachedTokens += u.cached;
  usageTotals.outputTokens += u.output;
  usageTotals.usd += usd;
  const s = (usageTotals.perStep[step] ||= { calls: 0, usd: 0 });
  s.calls += 1;
  s.usd += usd;
  console.log(`[usage] ${providerName()} ${step} ${model} in=${u.input} cached=${u.cached} out=${u.output} ~$${usd.toFixed(4)}`);
}

export function uploadFile(args) {
  return provider().uploadFile(args);
}

/**
 * parts: [{kind:'file', fileId, mimeType} | {kind:'text', text}] - dat tai lieu len dau de duoc cache.
 * Tra ve { json, citations }.
 */
export async function generateJson({ step, kind, system, parts, schemaName, schema, webSearch = false, timeoutMs = 34000, maxAttempts }) {
  const model = modelFor(kind);
  const reservation = await consumeStudyQuota(step);
  const signal = AbortSignal.timeout(timeoutMs);
  const attempts = currentStudyAccount() ? 1 : maxAttempts;
  let result;
  try {
    result = await provider().generate({ model, system, parts, schemaName, schema, webSearch, signal, maxAttempts: attempts });
  } catch (error) {
    if (signal.aborted) throw fail(504, 'AI chưa trả lời kịp. Hãy thử lại bước này.');
    throw error;
  }
  const { text, citations, usage } = result;
  record(step, model, usage);
  await recordStudyUsage(reservation, usage);
  if (!text) throw fail(502, 'AI khong tra ve noi dung');
  let json;
  try {
    json = JSON.parse(text.trim().replace(/^```(?:json)?\s*|\s*```$/g, ''));
  } catch {
    throw fail(502, 'AI tra ve dinh dang khong hop le');
  }
  return { json: repairLatex(json), citations };
}

// Lenh LaTeX bat dau bang n (sau khi "\n" bi doc thanh xuong dong): \neq, \nu, \nabla, \not, \ne, \ni, \neg...
const N_COMMANDS = /^(eq|e|u|abla|ot|eg|i|leq|geq|subseteq|parallel|mid|exists|ewline|Rightarrow|Leftrightarrow)\b/;

/**
 * AI hay viet "\frac", "\text", "\beta"... trong JSON ma khong nhan doi dau "\",
 * khi parse thanh ky tu dieu khien (\f form feed, \t tab, \b backspace, \r). Sua lai ve dang LaTeX.
 */
export function repairLatex(value) {
  if (typeof value === 'string') {
    let s = value
      .replace(/\f/g, '\\f')
      .replace(/\t/g, '\\t')
      .replace(/\x08/g, '\\b')
      .replace(/\r(?=[a-zA-Z])/g, '\\r');
    // "\n" + lenh LaTeX chi sua khi nam trong $...$
    s = s.replace(/\$\$[\s\S]*?\$\$|\$[^$]*\$/g, (m) => m.replace(/\n(?=[a-zA-Z])/g, (nl, off) => (N_COMMANDS.test(m.slice(off + 1)) ? '\\n' : nl)));
    return s;
  }
  if (Array.isArray(value)) return value.map(repairLatex);
  if (value && typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = k === 'source' || k === 'html' ? v : repairLatex(v); // code/HTML giu nguyen
    return out;
  }
  return value;
}
