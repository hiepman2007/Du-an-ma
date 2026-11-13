import { wrap } from '../../lib/http.js';
import { createStudyQuiz } from '../../lib/study.js';

export default wrap(async (req, res) => {
  res.status(200).json(await createStudyQuiz(req.body));
});
