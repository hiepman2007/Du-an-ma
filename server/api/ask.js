import { wrap, fail } from '../lib/http.js';
import { generateJson } from '../lib/ai.js';
import { blocksOnlySchema } from '../lib/schemas.js';
import { askSystem } from '../lib/prompts.js';
import { buildParts, allowedUrlSet } from '../lib/content.js';
import { cleanBlocks } from '../lib/validate.js';
import { resolveImages } from '../lib/images.js';

const MAX_HISTORY = 6;

// Body: { role, subject?, lessonTitle?, question, history?: [{from:'user'|'tutor', text}], fileId?, mimeType?, text?, sources? }
//   -> { blocks[] }   (cau tra loi la chuoi khoi, app dung lai BlockRenderer)
export default wrap(async (req, res) => {
  const { role, subject, lessonTitle, question, history, fileId, mimeType, text, sources } = req.body || {};
  if (!question || String(question).length > 1000) throw fail(400, 'Cau hoi trong hoac qua dai (toi da 1000 ky tu)');
  const convo = (Array.isArray(history) ? history : [])
    .slice(-MAX_HISTORY)
    .map((m) => `${m.from === 'user' ? 'Người học' : 'Gia sư'}: ${String(m.text || '').slice(0, 600)}`)
    .join('\n');
  const instruction = [
    lessonTitle ? `Bài đang học: ${lessonTitle}${subject ? ` (môn ${subject})` : ''}.` : '',
    convo ? `Hội thoại trước đó:\n${convo}` : '',
    `Câu hỏi mới của người học: ${question}`,
  ].filter(Boolean).join('\n\n');
  // Khong co tai lieu (hoi tu do) van tra loi duoc.
  const parts = fileId || text || (sources && sources.length)
    ? buildParts({ fileId, mimeType, text, sources, instruction })
    : [{ kind: 'text', text: instruction }];
  const { json } = await generateJson({
    step: 'ask',
    kind: 'lesson',
    system: askSystem(role),
    parts,
    schemaName: 'tutor_answer',
    schema: blocksOnlySchema,
  });
  const blocks = await resolveImages(cleanBlocks(json.blocks, { allowedUrls: allowedUrlSet(sources) }).slice(0, 5));
  if (!blocks.length) throw fail(502, 'AI chua tra loi duoc, hay hoi lai theo cach khac');
  res.status(200).json({ blocks });
});
