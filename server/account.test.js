import assert from 'node:assert/strict';
import { test } from 'node:test';
import { currentStudyAccount, consumeStudyQuota, resolveStudyFiles } from './lib/account.js';
import { wrap } from './lib/http.js';

const owner = '830003cd-a877-4fc8-9f8c-e551c8b19925';
const notebook = 'study-notebook';
const path = `${owner}/${notebook}/private-file`;

function reply() {
  return {
    code: 0, body: null, headers: {},
    setHeader(key, value) { this.headers[key] = value; },
    status(code) { this.code = code; return this; },
    json(body) { this.body = body; },
    end() {},
  };
}

function request(body, headers = {}) {
  return { url: '/api/study/artifact', method: 'POST', body, headers, socket: { remoteAddress: '127.0.0.1' } };
}

test('cloud routes verify account and notebook, isolate private files and count actual owner quota', async (t) => {
  const env = {
    STUDY_REQUIRE_AUTH: 'true', SUPABASE_URL: 'https://example.test', SUPABASE_PUBLISHABLE_KEY: 'publishable',
    SUPABASE_SECRET_KEY: 'server-secret', STUDY_PRIVATE_AI_ENABLED: 'true', APP_TOKEN: 'local-token',
  };
  const oldEnv = Object.fromEntries(Object.keys(env).map((key) => [key, process.env[key]]));
  Object.assign(process.env, env);
  t.after(() => {
    for (const [key, value] of Object.entries(oldEnv)) {
      if (value == null) delete process.env[key];
      else process.env[key] = value;
    }
  });

  let quota = 0;
  let loads = 0;
  t.mock.method(globalThis, 'fetch', async (url, init) => {
    const target = new URL(url);
    if (target.pathname === '/auth/v1/user') {
      assert.equal(init.headers.apikey, 'publishable');
      if (init.headers.Authorization !== 'Bearer signed-user') return new Response('', { status: 401 });
      return Response.json({ id: owner, email_confirmed_at: '2026-11-13T00:00:00Z' });
    }
    if (target.pathname === '/rest/v1/study_notebooks') {
      assert.equal(init.headers.Authorization, 'Bearer signed-user');
      assert.equal(target.searchParams.get('owner_id'), `eq.${owner}`);
      return Response.json(target.searchParams.get('notebook_id') === `eq.${notebook}` ? [{ document: {
        sources: [{ id: 'private-file', kind: 'file', title: 'Course PDF', storage_path: path, mimeType: 'application/pdf' }],
      } }] : []);
    }
    if (target.pathname === `/storage/v1/object/authenticated/study-sources/${path}`) {
      assert.equal(init.headers.Authorization, 'Bearer signed-user');
      loads++;
      return new Response('%PDF-1.4');
    }
    if (target.pathname === '/rest/v1/rpc/study_reserve_usage') {
      assert.equal(init.headers.apikey, 'server-secret');
      const body = JSON.parse(init.body);
      assert.equal(body.p_owner, owner);
      assert.equal(body.p_category, 'model');
      return quota++ ? new Response('', { status: 429 }) : Response.json(91);
    }
    throw new Error('Unexpected upstream request');
  });

  const handler = wrap(async (req, res) => {
    const material = await resolveStudyFiles(req.body, async ({ buffer, mimeType }) => {
      assert.equal(buffer.toString(), '%PDF-1.4');
      assert.equal(mimeType, 'application/pdf');
      return 'provider-handle';
    });
    const reservation = await consumeStudyQuota('quiz');
    res.status(200).json({ owner: currentStudyAccount().id, files: material.files, reservation });
  });
  const bearer = { authorization: 'Bearer signed-user' };
  const body = { notebook_id: notebook, files: [{ id: 'private-file', storage_path: path, mimeType: 'image/webp' }] };
  const cases = [
    [request(body, { 'x-app-token': 'local-token' }), 401],
    [request(body, { authorization: 'Bearer expired' }), 401],
    [request({ ...body, notebook_id: 'another-notebook' }, bearer), 404],
    [request({ ...body, files: [{ id: 'private-file', storage_path: `${owner}/wrong-notebook/private-file` }] }, bearer), 403],
    [request({ ...body, files: [{ id: 'private-file', fileId: 'supplied-provider-handle', storage_path: path }] }, bearer), 422],
    [request(body, bearer), 200],
    [request(body, bearer), 429],
  ];
  for (const [req, status] of cases) {
    const res = reply();
    await handler(req, res);
    assert.equal(res.code, status);
    if (status === 200) {
      assert.deepEqual(res.body, { owner, reservation: 91, files: [{
        id: 'private-file', name: 'Course PDF', mimeType: 'application/pdf', fileId: 'provider-handle', pages: [],
      }] });
    }
  }
  assert.equal(loads, 1);
  assert.equal(quota, 2);
});
