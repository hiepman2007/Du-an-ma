import { wrap, fail } from '../lib/http.js';
import { generateJson } from '../lib/ai.js';
import { simulationSchema } from '../lib/schemas.js';
import { simulationSystem } from '../lib/prompts.js';
import { sanitizeSimulationHtml, unwrapSimulationHtml } from '../lib/validate.js';

// Body: { role, lessonTitle, simPrompt, topic?, previousHtml? } -> { title, instructions, html }
// Mo phong tuy bien kieu Canvas: HTML tu chua, chay trong khung cach ly (CSP chan moi ket noi ngoai).
// Co previousHtml: sua tiep ban hien tai theo yeu cau (simPrompt), giu nguyen phan khong duoc yeu cau doi.
export default wrap(async (req, res) => {
  const { role, lessonTitle, simPrompt, topic, previousHtml } = req.body || {};
  if (!simPrompt || String(simPrompt).length > 600) throw fail(400, 'Thieu mo ta mo phong');
  const previous = unwrapSimulationHtml(previousHtml);
  const text = previous
    ? `Bai hoc: ${lessonTitle || ''}
Chu de: ${topic || ''}
Day la ban mo phong hien tai:
<<<HTML
${previous}
HTML>>>
`
      + `Yeu cau chinh sua cua hoc sinh: ${simPrompt}
`
      + 'Sua dung theo yeu cau, giu nguyen cac phan khac dang chay tot. Tra ve TOAN BO trang HTML moi (khong chi doan thay doi). '
      + 'instructions mo ta ngan gon da thay doi gi va hoc sinh nen thu gi.'
    : `Bai hoc: ${lessonTitle || ''}
Chu de: ${topic || ''}
Mo phong can tao: ${simPrompt}`;
  for (let attempt = 0; attempt < 2; attempt++) {
    const { json } = await generateJson({
      step: previous ? 'simulation-revise' : 'simulation',
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
