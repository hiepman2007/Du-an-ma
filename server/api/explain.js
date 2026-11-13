import { wrap, fail } from '../lib/http.js';
import { generateJson } from '../lib/ai.js';
import { explainSchema } from '../lib/schemas.js';
import { explainSystem } from '../lib/prompts.js';

// Body: { role, question, options?, chosen, correct, sourceQuote? } -> { hint, explanation, root_cause, weak_topic }
export default wrap(async (req, res) => {
  const { role, question, options, chosen, correct, sourceQuote } = req.body || {};
  if (!question) throw fail(400, 'Thieu cau hoi');
  const text = [
    `Cau hoi: ${question}`,
    options?.length ? `Lua chon: ${options.join(' | ')}` : '',
    `Hoc sinh tra loi: ${chosen}`,
    `Dap an dung: ${correct}`,
    sourceQuote ? `Doan trich nguon: ${sourceQuote}` : '',
  ].filter(Boolean).join('\n');
  const { json } = await generateJson({
    step: 'explain',
    kind: 'small',
    system: explainSystem(role),
    parts: [{ kind: 'text', text }],
    schemaName: 'explain',
    schema: explainSchema,
  });
  res.status(200).json(json);
});
