import { wrap, fail } from '../lib/http.js';
import { generateJson } from '../lib/ai.js';
import { blocksOnlySchema, INTERACTIVE_TYPES } from '../lib/schemas.js';
import { interactiveSystem } from '../lib/prompts.js';
import { buildParts, allowedUrlSet } from '../lib/content.js';
import { cleanBlocks } from '../lib/validate.js';

// Body: { role, lessonTitle, subject?, concept, fileId?, mimeType?, text?, sources? } -> { blocks[] }
export default wrap(async (req, res) => {
  const { role, lessonTitle, subject, concept, fileId, mimeType, text, sources } = req.body || {};
  if (!concept) throw fail(400, 'Thieu khai niem can kham pha');
  const parts = buildParts({
    fileId, mimeType, text, sources,
    instruction: `Bài học: ${lessonTitle || ''}${subject ? ` (môn ${subject})` : ''}. Khái niệm cần khám phá: ${concept}. Tạo 1-2 khối tương tác/thực nghiệm phù hợp nhất.`,
  });
  const { json } = await generateJson({
    step: 'interactive',
    kind: 'small',
    system: interactiveSystem(role),
    parts,
    schemaName: 'interactive_blocks',
    schema: blocksOnlySchema,
  });
  const blocks = cleanBlocks(json.blocks, { allowedUrls: allowedUrlSet(sources) }).filter((b) => INTERACTIVE_TYPES.includes(b.type));
  if (!blocks.length) throw fail(502, 'AI khong tao duoc khoi tuong tac hop le, hay thu lai');
  res.status(200).json({ blocks });
});
