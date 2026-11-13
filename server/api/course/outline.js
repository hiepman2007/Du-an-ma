import { wrap } from '../../lib/http.js';
import { generateJson } from '../../lib/ai.js';
import { outlineSchema } from '../../lib/schemas.js';
import { outlineSystem } from '../../lib/prompts.js';
import { buildParts } from '../../lib/content.js';

// Body: { role, goal, fileId?, mimeType?, text?, sources? } -> Course { title, language, lessons[] }
export default wrap(async (req, res) => {
  const { role, goal, files, fileId, mimeType, text, sources } = req.body || {};
  const parts = buildParts({
    files, fileId, mimeType, text, sources,
    instruction: `Muc tieu cua nguoi hoc: ${goal || 'nam vung noi dung tai lieu'}. Hay lap lo trinh khoa hoc.`,
  });
  const { json } = await generateJson({
    step: 'outline',
    kind: 'outline',
    system: outlineSystem(role),
    parts,
    schemaName: 'course_outline',
    schema: outlineSchema,
  });
  res.status(200).json(json);
});
