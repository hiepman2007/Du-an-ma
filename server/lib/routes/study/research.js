import { wrap } from '../../http.js';
import { consumeStudyQuota } from '../../account.js';
import { findStudySources } from '../../research.js';

export default wrap(async (req, res) => {
  const result = await findStudySources(req.body, {
    reserve: () => consumeStudyQuota('study-research', { category: 'search' }),
  });
  res.status(200).json(result);
});
