import { wrap, fail } from '../lib/http.js';
import { generateJson } from '../lib/ai.js';
import { blocksOnlySchema } from '../lib/schemas.js';
import { exercisesSystem } from '../lib/prompts.js';
import { buildParts, allowedUrlSet } from '../lib/content.js';
import { cleanBlocks } from '../lib/validate.js';

const EXERCISE_TYPES = ['mcq', 'true_false', 'fill_blank', 'step_solver', 'matching', 'ordering'];

// Body: { role, subject?, lessonTitle, objectives?, difficulty: easy|medium|hard, count?, existing?: [string],
//         fileId?, mimeType?, text?, sources? } -> { blocks[] }
export default wrap(async (req, res) => {
  const { role, subject, lessonTitle, objectives, difficulty, count, existing, fileId, mimeType, text, sources } = req.body || {};
  if (!lessonTitle) throw fail(400, 'Thieu ten bai hoc');
  const n = Math.min(Math.max(Number(count) || 5, 1), 8);
  const parts = buildParts({
    fileId, mimeType, text, sources,
    instruction: [
      `Bài: ${lessonTitle}${subject ? ` (môn ${subject})` : ''}. Mục tiêu: ${(objectives || []).join('; ')}.`,
      `Hãy soạn đúng ${n} câu luyện tập.`,
      existing?.length ? `Các câu đã có (không lặp lại):\n- ${existing.slice(0, 30).map((q) => String(q).slice(0, 160)).join('\n- ')}` : '',
    ].filter(Boolean).join('\n'),
  });
  const { json } = await generateJson({
    step: 'exercises',
    kind: 'lesson',
    system: exercisesSystem(role, difficulty),
    parts,
    schemaName: 'exercises',
    schema: blocksOnlySchema,
  });
  const blocks = cleanBlocks(json.blocks, { allowedUrls: allowedUrlSet(sources) })
    .filter((b) => EXERCISE_TYPES.includes(b.type))
    .slice(0, n)
    .map((b) => ({ ...b, difficulty: difficulty || 'medium' }));
  if (!blocks.length) throw fail(502, 'AI chua soan duoc cau hop le, hay thu lai');
  res.status(200).json({ blocks });
});
