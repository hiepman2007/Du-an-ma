import { wrap, fail } from '../lib/http.js';
import { generateJson } from '../lib/ai.js';
import { blocksOnlySchema } from '../lib/schemas.js';
import { askSystem } from '../lib/prompts.js';
import { buildParts, allowedUrlSet, hasMaterial } from '../lib/content.js';
import { cleanBlocks } from '../lib/validate.js';
import { resolveImages } from '../lib/images.js';
import { generateWithWeb } from '../lib/websearch.js';
import { queriesFor } from '../lib/wiki.js';

const MAX_HISTORY = 6;

// Body: { role, subject?, lessonTitle?, question, history?: [{from:'user'|'tutor', text}], webSearch?: bool, socratic?: bool,
//         files?, fileId?, mimeType?, text?, sources? }
//   -> { blocks[], web: [{title,url,domain,snippet,trust}], webMode: 'off'|'search'|'wikipedia' }
// Mac dinh (webSearch=false) chi tra loi tu cac nguon da nap, giong NotebookLM.
export default wrap(async (req, res) => {
  const { role, subject, lessonTitle, question, history, webSearch, socratic, files, fileId, mimeType, text, sources } = req.body || {};
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
  const material = { files, fileId, mimeType, text, sources };
  const parts = hasMaterial(material) ? buildParts({ ...material, instruction }) : [{ kind: 'text', text: instruction }];
  const common = {
    step: 'ask',
    kind: 'lesson',
    system: askSystem(role, { web: !!webSearch, hasSources: hasMaterial(material), socratic: socratic === true }),
    schemaName: 'tutor_answer',
    schema: blocksOnlySchema,
  };

  let json, web = [], webMode = 'off';
  if (webSearch) {
    ({ json, web, webMode } = await generateWithWeb({ ...common, parts, fallbackQuery: queriesFor(question, [lessonTitle]) }));
  } else {
    ({ json } = await generateJson({ ...common, parts }));
  }
  const allowed = new Set([...allowedUrlSet(sources), ...web.map((w) => w.url)]);
  const blocks = await resolveImages(cleanBlocks(json.blocks, { allowedUrls: allowed }).slice(0, 5));
  if (!blocks.length) throw fail(502, 'AI chua tra loi duoc, hay hoi lai theo cach khac');
  res.status(200).json({ blocks, web, webMode });
});
