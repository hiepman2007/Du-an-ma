import { wrap } from '../../http.js';
import { consumeStudyQuota } from '../../account.js';
import { readStudyUrl } from '../../research.js';

export default wrap(async (req, res) => {
  const source = await readStudyUrl(req.body?.url, {
    reserve: () => consumeStudyQuota('study-source', { category: 'search' }),
  });
  res.status(200).json({ source });
});
