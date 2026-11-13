import { getDocumentProxy } from 'unpdf';

const PAGE_LIMIT = 16;
const TOTAL_TEXT_LIMIT = 24000;
const PAGE_TEXT_LIMIT = 3500;

/** Extract a bounded text snapshot for page citations. Scans still work as files. */
export async function extractPdfPages(buffer) {
  if (!buffer?.length || buffer.length > 10 * 1024 * 1024) return [];
  const pages = [];
  let remaining = TOTAL_TEXT_LIMIT;
  let document;
  try {
    document = await getDocumentProxy(new Uint8Array(buffer), {
      isEvalSupported: false,
      useWasm: false,
      verbosity: 0,
    });
    for (let number = 1; number <= Math.min(document.numPages, PAGE_LIMIT) && remaining > 0; number++) {
      const page = await document.getPage(number);
      const { items } = await page.getTextContent();
      const text = items.map(({ str }) => str || '').join(' ').replace(/\s+/g, ' ').trim()
        .slice(0, Math.min(PAGE_TEXT_LIMIT, remaining));
      if (text) pages.push({ page: number, text });
      remaining -= text.length;
    }
  } catch {
    // Malformed, encrypted or scanned PDFs can still be passed as media.
  } finally {
    if (document) await document.loadingTask.destroy().catch(() => {});
  }
  return pages;
}
