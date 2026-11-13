import { wrap } from '../../http.js';
import { createStudyArtifact } from '../../study.js';

export default wrap(async (req, res) => {
  res.status(200).json(await createStudyArtifact(req.body));
});
