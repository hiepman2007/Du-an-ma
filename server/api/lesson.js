import { wrap, fail } from '../lib/http.js';
import { generateJson } from '../lib/ai.js';
import { lessonSchema } from '../lib/schemas.js';
import { lessonSystem } from '../lib/prompts.js';
import { buildParts, allowedUrlSet } from '../lib/content.js';
import { cleanBlocks } from '../lib/validate.js';
import { resolveImages } from '../lib/images.js';

// Body: { role, course:{title,subject?,lessons[]}, lessonId, fileId?, mimeType?, text?, sources? } -> { title, blocks[] }
export default wrap(async (req, res) => {
  const { role, course, lessonId, files, fileId, mimeType, text, sources } = req.body || {};
  const lesson = course?.lessons?.find((l) => l.id === lessonId);
  if (!lesson) throw fail(400, 'Khong tim thay bai hoc');
  const parts = buildParts({
    files, fileId, mimeType, text, sources,
    instruction: [
      `Khóa học: ${course.title}${course.subject ? ` (môn ${course.subject})` : ''}.`,
      `Hãy tạo bài học "${lesson.title}". Mục tiêu: ${(lesson.objectives || []).join('; ')}.`,
      lesson.interaction_hint ? `Gợi ý tương tác: ${lesson.interaction_hint}.` : '',
    ].filter(Boolean).join(' '),
  });
  const { json } = await generateJson({
    step: 'lesson',
    kind: 'lesson',
    system: lessonSystem(role),
    parts,
    schemaName: 'lesson',
    schema: lessonSchema,
  });
  const blocks = await resolveImages(cleanBlocks(json.blocks, { allowedUrls: allowedUrlSet(sources) }));
  if (blocks.length < 2) throw fail(502, 'AI khong tao du noi dung hop le, hay thu lai');
  res.status(200).json({ title: json.title, blocks });
});
