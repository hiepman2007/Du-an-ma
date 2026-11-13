import artifact from '../../lib/routes/study/artifact.js';
import ask from '../../lib/routes/study/ask.js';
import lesson from '../../lib/routes/study/lesson.js';
import outline from '../../lib/routes/study/outline.js';
import quiz from '../../lib/routes/study/quiz.js';
import research from '../../lib/routes/study/research.js';
import source from '../../lib/routes/study/source.js';

// Mot ham Vercel cho moi /api/study/<action> (goi Hobby gioi han 12 ham moi lan deploy).
const handlers = { artifact, ask, lesson, outline, quiz, research, source };

export function studyAction(req) {
  const fromQuery = req.query?.action;
  if (typeof fromQuery === 'string') return fromQuery;
  return new URL(req.url || '/', 'http://localhost').pathname.split('/').filter(Boolean).pop() || '';
}

export default async function handler(req, res) {
  const action = studyAction(req);
  if (!Object.hasOwn(handlers, action)) {
    res.status(404).json({ error: 'Không tìm thấy API.' });
    return;
  }
  return handlers[action](req, res);
}
