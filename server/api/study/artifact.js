import { wrap } from '../../lib/http.js';
import { createStudyArtifact } from '../../lib/study.js';

export default wrap(async (req, res) => {
  res.status(200).json(await createStudyArtifact(req.body));
});
