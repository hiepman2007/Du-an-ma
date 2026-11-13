import { wrap } from '../../lib/http.js';
import { consumeStudyQuota } from '../../lib/account.js';
import { findStudySources } from '../../lib/research.js';

export default wrap(async (req, res) => {
  const result = await findStudySources(req.body, {
    reserve: () => consumeStudyQuota('study-research', { category: 'search' }),
  });
  res.status(200).json(result);
});
