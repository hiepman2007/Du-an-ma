// Lop trung gian chon nha cung cap AI: AI_PROVIDER=openai | gemini (mac dinh: gemini neu chi co GEMINI_API_KEY).
import { fail } from './http.js';
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

/** Model theo buoc: MODEL_OUTLINE / MODEL_LESSON / MODEL_SMALL (cho nha cung cap dang dung), de trong thi dung mac dinh. */
export function modelFor(kind) {
  const env = { outline: process.env.MODEL_OUTLINE, lesson: process.env.MODEL_LESSON, small: process.env.MODEL_SMALL }[kind];
  return env || DEFAULT_MODELS[providerName()][kind];
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
export async function generateJson({ step, kind, system, parts, schemaName, schema, webSearch = false }) {
  const model = modelFor(kind);
  const { text, citations, usage } = await provider().generate({ model, system, parts, schemaName, schema, webSearch });
  record(step, model, usage);
  if (!text) throw fail(502, 'AI khong tra ve noi dung');
  let json;
  try {
    json = JSON.parse(text.trim().replace(/^```(?:json)?\s*|\s*```$/g, ''));
  } catch {
    throw fail(502, 'AI tra ve dinh dang khong hop le');
  }
  return { json, citations };
}
