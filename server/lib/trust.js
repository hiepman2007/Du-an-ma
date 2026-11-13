// Gan nhan tin cay theo ten mien (danh sach don gian, dat o server de sua nhanh).
const TRUSTED_SUFFIXES = ['.edu', '.edu.vn', '.ac.uk', '.ac.vn', '.gov', '.gov.vn', '.ac.jp', '.edu.au'];
const TRUSTED_HOSTS = [
  'wikipedia.org', 'khanacademy.org', 'openstax.org', 'ocw.mit.edu', 'britannica.com',
  'nature.com', 'sciencedirect.com', 'who.int', 'un.org', 'coursera.org', 'moet.gov.vn',
];

export function hostOf(url) {
  try { return new URL(url).hostname.replace(/^www\./, ''); } catch { return ''; }
}

export function trustOf(url) {
  const host = hostOf(url);
  if (!host) return 'check';
  if (TRUSTED_SUFFIXES.some((s) => host.endsWith(s))) return 'trusted';
  if (TRUSTED_HOSTS.some((h) => host === h || host.endsWith('.' + h))) return 'trusted';
  return 'check';
}
