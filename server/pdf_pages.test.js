import test from 'node:test';
import assert from 'node:assert/strict';
import { extractPdfPages } from './lib/pdf_pages.js';
import uploadHandler from './api/upload.js';
import { resolveStudyFiles, withStudyAccount } from './lib/account.js';

function fixturePdf() {
  const text = 'BT /F1 12 Tf 20 90 Td (Study note on arrays) Tj ET';
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Count 2 /Kids [3 0 R 6 0 R] >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 240 120] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    `<< /Length ${text.length} >>\nstream\n${text}\nendstream`,
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 240 120] >>',
  ];
  let pdf = '%PDF-1.4\n';
  const offsets = ['0000000000 65535 f '];
  for (const [index, object] of objects.entries()) {
    offsets.push(`${String(pdf.length).padStart(10, '0')} 00000 n `);
    pdf += `${index + 1} 0 obj\n${object}\nendobj\n`;
  }
  return Buffer.from(`${pdf}xref\n0 ${offsets.length}\n${offsets.join('\n')}\ntrailer\n<< /Root 1 0 R /Size ${offsets.length} >>\nstartxref\n${pdf.length}\n%%EOF\n`);
}

test('extracts stable 1-based PDF page locations and skips blank pages', async () => {
  assert.deepEqual(await extractPdfPages(fixturePdf()), [{ page: 1, text: 'Study note on arrays' }]);
});

test('PDF evidence extraction tolerates malformed files and bounds input size', async () => {
  assert.deepEqual(await extractPdfPages(Buffer.from('not-a-pdf')), []);
  assert.deepEqual(await extractPdfPages(Buffer.alloc(11 * 1024 * 1024)), []);
});

function env(t, values) {
  const old = Object.fromEntries(Object.keys(values).map((key) => [key, process.env[key]]));
  for (const [key, value] of Object.entries(values)) {
    if (value == null) delete process.env[key];
    else process.env[key] = value;
  }
  t.after(() => {
    for (const [key, value] of Object.entries(old)) {
      if (value == null) delete process.env[key];
      else process.env[key] = value;
    }
  });
}

test('local upload returns the provider handle and PDF evidence from the same bytes', async (t) => {
  env(t, { STUDY_REQUIRE_AUTH: undefined, SUPABASE_URL: undefined, VERCEL: undefined,
    NODE_ENV: undefined, APP_TOKEN: 'fixture', AI_PROVIDER: 'gemini', GEMINI_API_KEY: 'test' });
  const bytes = fixturePdf();
  t.mock.method(globalThis, 'fetch', async (url, init) => {
    if (url.endsWith('/upload/v1beta/files')) return new Response('{}', { headers: { 'x-goog-upload-url': 'https://upload.test/pdf' } });
    assert.equal(url, 'https://upload.test/pdf');
    assert.deepEqual(init.body, bytes);
    return Response.json({ file: { uri: 'provider-handle' } });
  });
  const res = {
    code: 0, body: undefined, setHeader() {},
    status(code) { this.code = code; return this; },
    json(body) { this.body = body; },
  };
  await uploadHandler({ url: '/api/upload', method: 'POST', socket: { remoteAddress: '127.0.0.1' },
    headers: { 'x-app-token': 'fixture' }, body: { filename: 'study.pdf', mimeType: 'application/pdf', dataBase64: bytes.toString('base64') } }, res);
  assert.equal(res.code, 200);
  assert.deepEqual(res.body, { fileId: 'provider-handle', mimeType: 'application/pdf', pages: [{ page: 1, text: 'Study note on arrays' }] });
});

test('authenticated PDF citation pages are rebuilt from owned storage bytes', async (t) => {
  env(t, { SUPABASE_URL: 'https://storage.test', SUPABASE_PUBLISHABLE_KEY: 'public', STUDY_PRIVATE_AI_ENABLED: 'true' });
  const owner = '830003cd-a877-4fc8-9f8c-e551c8b19925';
  const notebook = 'pdf-citation-test';
  const path = `${owner}/${notebook}/fixture`;
  const bytes = fixturePdf();
  t.mock.method(globalThis, 'fetch', async (url, init) => {
    assert.equal(init.headers.Authorization, 'Bearer verified-test-token');
    if (url.includes('/rest/v1/study_notebooks')) return Response.json([{ document: { sources: [{
      id: 'fixture', kind: 'file', title: 'PDF', mimeType: 'application/pdf', storage_path: path,
    }] } }]);
    assert.equal(url, `https://storage.test/storage/v1/object/authenticated/study-sources/${path}`);
    return new Response(bytes);
  });
  const result = await withStudyAccount({ id: owner, token: 'verified-test-token' }, () => resolveStudyFiles({
    notebook_id: notebook, files: [{ id: 'fixture', storage_path: path, pages: [{ page: 99, text: 'Invented' }] }],
  }, async ({ buffer }) => {
    assert.deepEqual(buffer, bytes);
    return 'provider-handle';
  }));
  assert.deepEqual(result.files[0].pages, [{ page: 1, text: 'Study note on arrays' }]);
});
