// Tim anh minh hoa that tren Wikimedia Commons (giay phep tu do, co ghi tac gia). Khong de AI bia anh.
const API = 'https://commons.wikimedia.org/w/api.php';
const UA = 'HocThongMinh/0.1 (education demo app)';
const OK_LICENSE = /(cc0|cc[- ]by|public domain|pd-|gfdl)/i;

const strip = (s) => String(s || '').replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();

export async function findImage(query) {
  const params = new URLSearchParams({
    action: 'query', format: 'json', generator: 'search', gsrsearch: `${query} filetype:bitmap`,
    gsrnamespace: '6', gsrlimit: '5', prop: 'imageinfo', iiprop: 'url|extmetadata', iiurlwidth: '900', origin: '*',
  });
  try {
    const r = await fetch(`${API}?${params}`, { headers: { 'User-Agent': UA }, signal: AbortSignal.timeout(8000) });
    if (!r.ok) return null;
    const data = await r.json();
    const pages = Object.values(data?.query?.pages || {}).sort((a, b) => (a.index || 0) - (b.index || 0));
    for (const p of pages) {
      const info = p.imageinfo?.[0];
      const meta = info?.extmetadata || {};
      const license = strip(meta.LicenseShortName?.value);
      if (!info?.thumburl || !OK_LICENSE.test(license)) continue;
      return {
        url: info.thumburl,
        page_url: info.descriptionurl,
        license,
        author: strip(meta.Artist?.value).slice(0, 120) || 'Wikimedia Commons',
      };
    }
  } catch (e) {
    console.warn('[images]', String(e).slice(0, 200));
  }
  return null;
}

/** Gan anh that cho cac khoi image_card; bo khoi khong tim duoc anh. */
export async function resolveImages(blocks) {
  const out = await Promise.all(blocks.map(async (b) => {
    if (b.type !== 'image_card') return b;
    const image = await findImage(b.image_query);
    return image ? { ...b, image } : null;
  }));
  return out.filter(Boolean);
}
