import { wrap } from '../lib/http.js';
import { usageTotals } from '../lib/ai.js';

// So lieu chi phi that (trong bo nho cua instance hien tai; khoi dong lai se ve 0).
export default wrap(async (req, res) => {
  res.status(200).json(usageTotals);
}, { method: 'GET' });
