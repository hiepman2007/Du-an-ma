import { wrap } from '../../lib/http.js';
import { answerStudyQuestion } from '../../lib/study.js';

export default wrap(async (req, res) => {
  res.status(200).json(await answerStudyQuestion(req.body));
});
