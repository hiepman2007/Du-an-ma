import { wrap } from '../../lib/http.js';
import { consumeStudyQuota } from '../../lib/account.js';
import { readStudyUrl } from '../../lib/research.js';

export default wrap(async (req, res) => {
  const source = await readStudyUrl(req.body?.url, {
    reserve: () => consumeStudyQuota('study-source', { category: 'search' }),
  });
  res.status(200).json({ source });
});
