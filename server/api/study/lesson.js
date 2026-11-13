import { wrap } from '../../lib/http.js';
import { createStudyLesson } from '../../lib/study.js';

export default wrap(async (req, res) => {
  res.status(200).json(await createStudyLesson(req.body));
});
