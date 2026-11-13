import { wrap, fail } from '../lib/http.js';
import { generateJson } from '../lib/ai.js';
import { simulationSchema } from '../lib/schemas.js';
import { simulationSystem } from '../lib/prompts.js';
import { sanitizeSimulationHtml } from '../lib/validate.js';

// Body: { role, lessonTitle, simPrompt, topic? } -> { title, instructions, html }
// Mo phong tuy bien (tang du phong): HTML tu chua, chay trong khung cach ly (CSP chan moi ket noi ngoai).
export default wrap(async (req, res) => {
  const { role, lessonTitle, simPrompt, topic } = req.body || {};
  if (!simPrompt || String(simPrompt).length > 600) throw fail(400, 'Thieu mo ta mo phong');
  const text = `Bai hoc: ${lessonTitle || ''}\nChu de: ${topic || ''}\nMo phong can tao: ${simPrompt}`;
  for (let attempt = 0; attempt < 2; attempt++) {
    const { json } = await generateJson({
      step: 'simulation',
      kind: 'lesson',
      system: simulationSystem(role),
      parts: [{ kind: 'text', text }],
      schemaName: 'simulation',
      schema: simulationSchema,
    });
    const html = sanitizeSimulationHtml(json.html);
    if (html) return res.status(200).json({ title: json.title, instructions: json.instructions, html });
    console.warn('[simulation] HTML bi tu choi boi bo kiem tra, thu lai');
  }
  throw fail(502, 'AI chua tao duoc mo phong an toan, hay thu lai');
});
