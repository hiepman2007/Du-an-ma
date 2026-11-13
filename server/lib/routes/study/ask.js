import { wrap } from '../../http.js';
import { answerStudyQuestion } from '../../study.js';

export default wrap(async (req, res) => {
  res.status(200).json(await answerStudyQuestion(req.body));
});
