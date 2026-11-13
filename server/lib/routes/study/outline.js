import { wrap } from '../../http.js';
import { createStudyOutline } from '../../study.js';

export default wrap(async (req, res) => {
  res.status(200).json(await createStudyOutline(req.body));
});
