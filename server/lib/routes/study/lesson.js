import { wrap } from '../../http.js';
import { createStudyLesson } from '../../study.js';

export default wrap(async (req, res) => {
  res.status(200).json(await createStudyLesson(req.body));
});
