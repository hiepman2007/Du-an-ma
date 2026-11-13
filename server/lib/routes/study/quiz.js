import { wrap } from '../../http.js';
import { createStudyQuiz } from '../../study.js';

export default wrap(async (req, res) => {
  res.status(200).json(await createStudyQuiz(req.body));
});
