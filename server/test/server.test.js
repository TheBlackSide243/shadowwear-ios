import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, utimes } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createServer, makeSetupCode, sameSetupCode } from '../src/server.js';
import { Store } from '../src/store.js';
import { clean } from '../src/ollama.js';

const A = '6A9D6F1C-2E1B-4C55-9C4B-6C0F9D1E2A11';
const B = '0B1C2D3E-4F50-4612-8734-9A8B7C6D5E4F';
const O = 'C0FFEE00-1111-4222-8333-444455556666';
const W = 'DEADBEEF-1111-4222-8333-444455556666';

async function start(t, options = {}) {
  const dir = await mkdtemp(path.join(tmpdir(), 'sw-'));
  const app = await createServer({ dataDir: dir, ...options });
  await new Promise((r) => app.server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${app.server.address().port}`;
  t.after(async () => {
    await new Promise((r) => app.server.close(r));
    await rm(dir, { recursive: true, force: true });
  });
  return { ...app, base, dir };
}

async function call(base, method, pathname, { token, body, raw, headers = {} } = {}) {
  const res = await fetch(base + pathname, {
    method,
    headers: {
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...headers,
    },
    body: raw ?? (body ? JSON.stringify(body) : undefined),
  });
  const type = res.headers.get('content-type') ?? '';
  return { status: res.status, headers: res.headers, json: type.includes('json') ? await res.json() : null, res };
}

async function setup(base) {
  const r = await call(base, 'POST', '/api/setup', { body: { user: 'Anna', password: 'una password lunga', device: 'Test' } });
  assert.equal(r.status, 200);
  return r.json.token;
}

test('setup once, then login with user name and password', async (t) => {
  const { base } = await start(t);
  assert.equal((await call(base, 'GET', '/api/status')).json.configured, false);
  assert.equal((await call(base, 'GET', '/api/closet')).status, 401);
  assert.equal((await call(base, 'POST', '/api/setup', { body: { user: 'Anna', password: 'corta' } })).status, 400);
  assert.equal((await call(base, 'POST', '/api/setup', { body: { user: '', password: 'una password lunga' } })).status, 400);
  const token = await setup(base);
  assert.equal((await call(base, 'POST', '/api/setup', { body: { user: 'altro', password: "un'altra password" } })).status, 409);
  assert.equal((await call(base, 'GET', '/api/closet', { token })).status, 200);
  assert.equal((await call(base, 'POST', '/api/login', { body: { user: 'Anna', password: 'sbagliata!!' } })).status, 401);
  assert.equal((await call(base, 'POST', '/api/login', { body: { user: 'qualcuno', password: 'una password lunga' } })).status, 401);
  assert.equal((await call(base, 'POST', '/api/login', { body: { password: 'una password lunga' } })).status, 401);
  const login = await call(base, 'POST', '/api/login', { body: { user: 'anna', password: 'una password lunga', device: 'iPhone' } });
  assert.equal(login.status, 200);
  assert.match(login.headers.get('set-cookie'), /sw_session=.*HttpOnly; SameSite=Strict/);
  const devices = await call(base, 'GET', '/api/devices', { token: login.json.token });
  assert.deepEqual(devices.json.devices.map((d) => d.name).sort(), ['Test', 'iPhone']);
  assert.equal((await call(base, 'GET', '/api/account', { token })).json.user, 'Anna');
});

test('the first account only from the house; proxies pass the real address', async (t) => {
  const { base } = await start(t);
  const outside = { 'cf-connecting-ip': '203.0.113.7' };
  const r = await call(base, 'POST', '/api/setup', { body: { user: 'Anna', password: 'una password lunga' }, headers: outside });
  assert.equal(r.status, 403);
  const status = await call(base, 'GET', '/api/status');
  assert.equal(status.json.configured, false);
  assert.equal(status.json.needsSetupCode, false);
  assert.equal((await call(base, 'GET', '/api/status', { headers: outside })).json.needsSetupCode, true);
  await setup(base);
  // From the internet the login works, with the account.
  const login = await call(base, 'POST', '/api/login', { body: { user: 'Anna', password: 'una password lunga' }, headers: outside });
  assert.equal(login.status, 200);
});

test('change user name and password', async (t) => {
  const { base } = await start(t);
  const token = await setup(base);
  assert.equal((await call(base, 'POST', '/api/account', { token, body: { current: 'sbagliata!!', user: 'Nuovo' } })).status, 401);
  const renamed = await call(base, 'POST', '/api/account', { token, body: { current: 'una password lunga', user: 'Nuovo' } });
  assert.equal(renamed.status, 200);
  assert.equal(renamed.json.token, undefined);
  // Only the name changed: the device stays signed in.
  assert.equal((await call(base, 'GET', '/api/closet', { token })).status, 200);
  assert.equal((await call(base, 'POST', '/api/login', { body: { user: 'Anna', password: 'una password lunga' } })).status, 401);
  assert.equal((await call(base, 'POST', '/api/login', { body: { user: 'nuovo', password: 'una password lunga' } })).status, 200);
  const changed = await call(base, 'POST', '/api/account', { token, body: { current: 'una password lunga', next: 'password nuova!' } });
  assert.equal(changed.status, 200);
  assert.ok(changed.json.token);
  assert.equal((await call(base, 'GET', '/api/closet', { token })).status, 401);
  assert.equal((await call(base, 'GET', '/api/closet', { token: changed.json.token })).status, 200);
});

test('the web session needs its header to change things', async (t) => {
  const { base } = await start(t);
  const token = await setup(base);
  const cookie = `sw_session=${token}`;
  const item = { id: A, name: 'Maglia', category: 'top', updated: new Date().toISOString() };
  assert.equal((await call(base, 'PUT', `/api/items/${A}`, { body: item, headers: { cookie } })).status, 403);
  assert.equal((await call(base, 'PUT', `/api/items/${A}`, { body: item, headers: { cookie, 'x-shadowwear': 'web' } })).status, 200);
  assert.equal((await call(base, 'GET', '/api/closet', { headers: { cookie } })).json.items.length, 1);
});

test('two devices end up with the same closet', async (t) => {
  const { base } = await start(t);
  const token = await setup(base);
  const t1 = '2026-11-10T10:00:00Z';
  const t2 = '2026-11-11T10:00:00Z';

  // The iPhone has a piece and an outfit; the server is empty and asks for them.
  let answer = (await call(base, 'POST', '/api/sync/compare', {
    token,
    body: { items: [{ id: A, updated: t1 }], outfits: [{ id: O, updated: t1 }], wears: [W], deleted: [] },
  })).json;
  assert.deepEqual(answer.need, { items: [A], outfits: [O], wears: [W], wishes: [] });
  assert.deepEqual(answer.send, { items: [], outfits: [], wears: [], wishes: [] });
  await call(base, 'POST', '/api/sync/push', {
    token,
    body: {
      items: [{ id: A, name: 'Maglia', category: 'top', updated: t1, photos: [{ id: A }] }],
      outfits: [{ id: O, name: 'Weekend', items: [A], updated: t1 }],
      wears: [{ id: W, day: '2026-11-10', outfit: O, items: [A] }],
    },
  });

  // The iPad has nothing: it gets everything.
  answer = (await call(base, 'POST', '/api/sync/compare', { token, body: { items: [], outfits: [], wears: [], deleted: [] } })).json;
  assert.equal(answer.send.items[0].name, 'Maglia');
  assert.equal(answer.send.outfits[0].name, 'Weekend');
  assert.equal(answer.send.wears[0].day, '2026-11-10');

  // The iPad renames the piece later: the server asks for it, then the iPhone gets the new name.
  answer = (await call(base, 'POST', '/api/sync/compare', { token, body: { items: [{ id: A, updated: t2 }] } })).json;
  assert.deepEqual(answer.need.items, [A]);
  await call(base, 'POST', '/api/sync/push', { token, body: { items: [{ id: A, name: 'Maglia blu', category: 'top', updated: t2 }] } });
  answer = (await call(base, 'POST', '/api/sync/compare', { token, body: { items: [{ id: A, updated: t1 }] } })).json;
  assert.equal(answer.send.items[0].name, 'Maglia blu');
  assert.deepEqual(answer.need.items, []);

  // An older copy never wins.
  await call(base, 'POST', '/api/sync/push', { token, body: { items: [{ id: A, name: 'Vecchia', category: 'top', updated: t1 }] } });
  assert.equal((await call(base, 'GET', '/api/closet', { token })).json.items[0].name, 'Maglia blu');
});

test('a deletion reaches the other devices and is not undone by an old copy', async (t) => {
  const { base } = await start(t);
  const token = await setup(base);
  const t1 = '2026-11-10T10:00:00Z';
  await call(base, 'POST', '/api/sync/push', {
    token,
    body: {
      items: [{ id: A, name: 'Maglia', category: 'top', updated: t1 }, { id: B, name: 'Jeans', category: 'bottom', updated: t1 }],
      outfits: [{ id: O, name: 'Weekend', items: [A, B], updated: t1 }],
    },
  });
  // The iPhone deleted the top.
  const answer = (await call(base, 'POST', '/api/sync/compare', {
    token,
    body: { items: [{ id: B, updated: t1 }], outfits: [{ id: O, updated: t1 }], deleted: [{ kind: 'items', id: A, at: '2026-11-12T10:00:00Z' }] },
  })).json;
  assert.ok(answer.deleted.some((d) => d.id === A));
  // The outfit lost the piece and is newer now, so it comes back to the iPhone.
  assert.deepEqual(answer.send.outfits[0].items, [B]);
  // The iPad still has the old top: it is not asked for, and pushing it does nothing.
  const ipad = (await call(base, 'POST', '/api/sync/compare', { token, body: { items: [{ id: A, updated: t1 }, { id: B, updated: t1 }] } })).json;
  assert.deepEqual(ipad.need.items, []);
  await call(base, 'POST', '/api/sync/push', { token, body: { items: [{ id: A, name: 'Maglia', category: 'top', updated: t1 }] } });
  assert.deepEqual((await call(base, 'GET', '/api/closet', { token })).json.items.map((i) => i.id), [B]);
});

test('photos go up and come down, only real images', async (t) => {
  const { base } = await start(t);
  const token = await setup(base);
  const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(200, 7)]);
  assert.equal((await call(base, 'PUT', `/api/photos/${A}.jpg`, { token, raw: Buffer.from('ciao') })).status, 400);
  assert.equal((await call(base, 'PUT', `/api/photos/..%2Fx.jpg`, { token, raw: jpeg })).status, 400);
  assert.equal((await call(base, 'PUT', `/api/photos/${A}.jpg`, { token, raw: jpeg })).status, 200);
  const got = await call(base, 'GET', `/api/photos/${A}.jpg`, { token });
  assert.equal(got.status, 200);
  assert.equal(got.headers.get('content-type'), 'image/jpeg');
  assert.deepEqual(Buffer.from(await got.res.arrayBuffer()), jpeg);
  const again = await call(base, 'GET', `/api/photos/${A}.jpg`, { token, headers: { 'if-none-match': got.headers.get('etag') } });
  assert.equal(again.status, 304);
  const closet = await call(base, 'GET', '/api/closet', { token });
  assert.deepEqual(closet.json.photos, [`${A}.jpg`]);
});

test('unused photos are pruned only when old', async (t) => {
  const dir = path.join(tmpdir(), `sw-store-${Date.now()}`);
  t.after(() => rm(dir, { recursive: true, force: true }));
  const store = await new Store(dir).open();
  store.put('items', { id: A, name: 'x', category: 'top', updated: new Date().toISOString(), photos: [{ id: A }] });
  await store.writePhoto(`${A}.jpg`, Buffer.from([0xff, 0xd8]));
  await store.writePhoto(`${B}.jpg`, Buffer.from([0xff, 0xd8]));
  assert.equal(await store.prunePhotos(), 0);
  const old = new Date(Date.now() - 3 * 86_400_000);
  await utimes(store.photoPath(`${B}.jpg`), old, old);
  assert.equal(await store.prunePhotos(), 1);
  assert.deepEqual(await store.photoNames(), [`${A}.jpg`]);
});

test('the AI answer is kept to what the app knows', () => {
  const out = clean('{"name":"Felpa grigia","category":"top","colors":["grey","Grey","pink-ish","navy","black"],"warmth":"warm","notes":"Con i jeans."}');
  assert.equal(out.name, 'Felpa grigia');
  assert.equal(out.category, 'top');
  assert.deepEqual(out.colors, ['grey', 'navy', 'black']);
  assert.equal(out.warmth, 2);
  assert.equal(clean('{"category":"hat"}').category, 'other');
  const read = clean(`{"name":"T-shirt bianca","category":"top","colors":["white"],"brand":" Levi's ","size":"N/A"}`);
  assert.equal(read.brand, "Levi's");
  assert.equal(read.size, '');
  assert.equal(clean('{"brand":"unknown","size":"M"}').brand, '');
  assert.equal(clean('{"brand":"unknown","size":"M"}').size, 'M');
  assert.deepEqual(clean('{"colors":["bianco","Rossa","white","blu scuro","fluo"]}').colors, ['white', 'red', 'navy']);
  assert.equal(clean('ecco: {"name":"Scarpe","category":"shoes","colors":[],"warmth":"x"} fine').name, 'Scarpe');
});

test('describe asks Ollama with the photo and the chosen model', async (t) => {
  const asked = [];
  const fakeOllama = async (url, init) => {
    asked.push({ url, body: init?.body ? JSON.parse(init.body) : null });
    if (url.endsWith('/api/tags')) return Response.json({ models: [{ name: 'vista:7b', size: 1 }, { name: 'testo:3b', size: 1 }] });
    if (url.endsWith('/api/show')) return Response.json({ capabilities: JSON.parse(init.body).model === 'vista:7b' ? ['completion', 'vision'] : ['completion'] });
    return Response.json({ message: { content: '{"name":"Jeans dritti","category":"bottom","colors":["blue"],"warmth":"medium"}' } });
  };
  const { base } = await start(t, { ollamaURL: 'http://ollama:11434', fetcher: fakeOllama });
  const token = await setup(base);
  const models = await call(base, 'GET', '/api/ai/models', { token });
  assert.deepEqual(models.json.models.map((m) => [m.name, m.vision]), [['vista:7b', true], ['testo:3b', false]]);
  assert.equal((await call(base, 'POST', '/api/ai/describe', { token, raw: Buffer.alloc(500, 1) })).status, 502);
  await call(base, 'PUT', '/api/settings', { token, body: { aiModel: 'vista:7b' } });
  const described = await call(base, 'POST', '/api/ai/describe', { token, raw: Buffer.alloc(500, 1) });
  assert.equal(described.status, 200);
  assert.equal(described.json.category, 'bottom');
  const chat = asked.find((a) => a.url.endsWith('/api/chat'));
  assert.equal(chat.body.model, 'vista:7b');
  assert.equal(chat.body.messages[0].images.length, 1);
});

test('the web page and its files are served, nothing outside', async (t) => {
  const { base } = await start(t);
  const page = await fetch(`${base}/`);
  assert.equal(page.status, 200);
  assert.match(page.headers.get('content-security-policy'), /default-src 'self'/);
  assert.equal((await fetch(`${base}/app.js`)).status, 200);
  assert.equal((await fetch(`${base}/..%2Fpackage.json`)).status, 200); // falls back to the page
  assert.doesNotMatch(await (await fetch(`${base}/..%2Fpackage.json`)).text(), /"name"/);
});

test('the list of things to buy goes from one device to the other', async (t) => {
  const { base } = await start(t);
  const token = await setup(base);
  const L = '11111111-2222-4333-8444-555566667777';
  let answer = (await call(base, 'POST', '/api/sync/compare', { token, body: { wishes: [{ id: L, updated: '2026-11-10T10:00:00Z' }] } })).json;
  assert.deepEqual(answer.need.wishes, [L]);
  await call(base, 'POST', '/api/sync/push', {
    token,
    body: { wishes: [{ id: L, title: 'Giacca di lana', link: 'https://example.org/giacca', price: 89.9, updated: '2026-11-10T10:00:00Z' }] },
  });
  answer = (await call(base, 'POST', '/api/sync/compare', { token, body: { items: [], wishes: [] } })).json;
  assert.equal(answer.send.wishes[0].title, 'Giacca di lana');
  assert.equal(answer.send.wishes[0].price, 89.9);
  // Deleted on one device: gone for the others.
  await call(base, 'POST', '/api/sync/compare', { token, body: { deleted: [{ kind: 'wishes', id: L, at: '2026-11-11T10:00:00Z' }] } });
  answer = (await call(base, 'POST', '/api/sync/compare', { token, body: { wishes: [] } })).json;
  assert.deepEqual(answer.send.wishes, []);
  assert.ok(answer.deleted.some((d) => d.kind === 'wishes' && d.id === L));
});

test('the site reads and writes the things to buy', async (t) => {
  const { base } = await start(t);
  const token = await setup(base);
  const headers = { cookie: `sw_session=${token}`, 'x-shadowwear': 'web' };
  const W = '22222222-3333-4444-8555-666677778888';
  const wish = { id: W, title: 'Sneakers bianche', link: 'https://example.org/sneakers', price: 79, currency: 'EUR', bought: false };
  assert.equal((await call(base, 'PUT', `/api/wishes/${W}`, { body: wish, headers })).status, 200);
  const closet = (await call(base, 'GET', '/api/closet', { headers })).json;
  assert.equal(closet.wishes.length, 1);
  assert.equal(closet.wishes[0].title, 'Sneakers bianche');
  assert.ok(closet.wishes[0].created, 'the server dates a new wish');
  // The app gets it at the next sync.
  const answer = (await call(base, 'POST', '/api/sync/compare', { token, body: { wishes: [] } })).json;
  assert.equal(answer.send.wishes[0].price, 79);
  assert.equal((await call(base, 'DELETE', `/api/wishes/${W}`, { headers })).status, 200);
  assert.deepEqual((await call(base, 'GET', '/api/closet', { headers })).json.wishes, []);
});

test('the app asks its own questions to the model, with a photo or not', async (t) => {
  const asked = [];
  const fakeOllama = async (url, init) => {
    asked.push({ url, body: init?.body ? JSON.parse(init.body) : null });
    return Response.json({ message: { content: ' {"pieces":[2]} ' } });
  };
  const { base } = await start(t, { ollamaURL: 'http://ollama:11434', fetcher: fakeOllama });
  const token = await setup(base);
  // No model chosen yet.
  assert.equal((await call(base, 'POST', '/api/ai/chat', { token, body: { prompt: 'Ciao' } })).status, 503);
  await call(base, 'PUT', '/api/settings', { token, body: { aiModel: 'vista:7b' } });
  assert.equal((await call(base, 'POST', '/api/ai/chat', { token, body: {} })).status, 400);
  const photo = Buffer.alloc(500, 7).toString('base64');
  const r = await call(base, 'POST', '/api/ai/chat', { token, body: { system: 'Sei uno stylist.', prompt: 'Cosa indosso?', image: photo, json: true } });
  assert.equal(r.status, 200);
  assert.equal(r.json.text, '{"pieces":[2]}');
  const sent = asked.at(-1).body;
  assert.equal(sent.model, 'vista:7b');
  assert.equal(sent.format, 'json');
  assert.deepEqual(sent.messages.map((m) => m.role), ['system', 'user']);
  assert.equal(sent.messages[1].images[0], photo);
  // Not signed in: no.
  assert.equal((await call(base, 'POST', '/api/ai/chat', { body: { prompt: 'Ciao' } })).status, 401);
});

test('the address of Ollama is chosen on the site, and each iPhone may ask for its own model', async (t) => {
  const asked = [];
  const fakeOllama = async (url, init) => {
    asked.push({ url, body: init?.body ? JSON.parse(init.body) : null });
    if (url.endsWith('/api/tags')) return Response.json({ models: [{ name: url.includes('casa') ? 'vista:7b' : 'altro:1b', size: 1 }] });
    if (url.endsWith('/api/show')) return Response.json({ capabilities: ['vision'] });
    return Response.json({ message: { content: 'ok' } });
  };
  // No OLLAMA_URL: the site says so, and lets the user write one.
  const { base } = await start(t, { fetcher: fakeOllama });
  const token = await setup(base);
  assert.equal((await call(base, 'GET', '/api/status')).json.ai.available, false);
  assert.equal((await call(base, 'POST', '/api/ai/chat', { token, body: { prompt: 'Ciao' } })).status, 503);
  // Tried before saving: the models of that address.
  const tried = await call(base, 'GET', `/api/ai/models?url=${encodeURIComponent('casa:11434/api')}`, { token });
  assert.equal(tried.status, 200);
  assert.equal(tried.json.url, 'http://casa:11434');
  assert.deepEqual(tried.json.models.map((m) => m.name), ['vista:7b']);
  assert.equal((await call(base, 'GET', `/api/ai/models?url=${encodeURIComponent('ftp://casa')}`, { token })).status, 400);
  assert.equal((await call(base, 'PUT', '/api/settings', { token, body: { ollamaURL: 'file:///etc' } })).status, 400);
  const saved = await call(base, 'PUT', '/api/settings', { token, body: { ollamaURL: 'http://casa:11434/', aiModel: 'vista:7b' } });
  assert.equal(saved.json.ollamaURL, 'http://casa:11434');
  assert.equal(saved.json.ollamaInUse, 'http://casa:11434');
  assert.equal((await call(base, 'GET', '/api/status')).json.ai.available, true);
  // The server's model, or the one this iPhone asks for.
  await call(base, 'POST', '/api/ai/chat', { token, body: { prompt: 'Ciao' } });
  assert.equal(asked.at(-1).url, 'http://casa:11434/api/chat');
  assert.equal(asked.at(-1).body.model, 'vista:7b');
  await call(base, 'POST', '/api/ai/chat', { token, body: { prompt: 'Ciao', model: 'mio:3b' } });
  assert.equal(asked.at(-1).body.model, 'mio:3b');
  await call(base, 'POST', `/api/ai/describe?lang=it&model=${encodeURIComponent('hf.co/a/b:Q4')}`, { token, raw: Buffer.alloc(500, 1) });
  assert.equal(asked.at(-1).body.model, 'hf.co/a/b:Q4');
  // Not signed in: no trying addresses.
  assert.equal((await call(base, 'GET', `/api/ai/models?url=casa`)).status, 401);
});

test('OLLAMA_URL stays the default until the site chooses another address', async (t) => {
  const fakeOllama = async () => Response.json({ models: [] });
  const { base } = await start(t, { ollamaURL: 'http://nas:11434', fetcher: fakeOllama });
  const token = await setup(base);
  let s = (await call(base, 'GET', '/api/settings', { token })).json;
  assert.equal(s.ollamaURL, '');
  assert.equal(s.ollamaDefault, 'http://nas:11434');
  assert.equal(s.ollamaInUse, 'http://nas:11434');
  s = (await call(base, 'PUT', '/api/settings', { token, body: { ollamaURL: 'http://pc:11434' } })).json;
  assert.equal(s.ollamaInUse, 'http://pc:11434');
  // Back to the default by emptying the field.
  s = (await call(base, 'PUT', '/api/settings', { token, body: { ollamaURL: '' } })).json;
  assert.equal(s.ollamaURL, '');
  assert.equal(s.ollamaInUse, 'http://nas:11434');
});

test('from the internet the first account needs the setup code of the log', async (t) => {
  const { base, setupCode } = await start(t);
  const outside = { 'cf-connecting-ip': '203.0.113.7' };
  const body = { user: 'Anna', password: 'una password lunga' };
  assert.equal((await call(base, 'POST', '/api/setup', { body: { ...body, setupCode: 'AAAAAAAAAAAA' }, headers: outside })).status, 403);
  assert.equal((await call(base, 'POST', '/api/setup', { body: { ...body, setupCode: '' }, headers: outside })).status, 403);
  // Typed in lower case and with dashes, as people copy it.
  const typed = setupCode.toLowerCase().replace(/(.{4})(?!$)/g, '$1-');
  const r = await call(base, 'POST', '/api/setup', { body: { ...body, setupCode: typed }, headers: outside });
  assert.equal(r.status, 200);
  assert.equal((await call(base, 'GET', '/api/status', { headers: outside })).json.needsSetupCode, false);
});

test('a setup code chosen with SETUP_CODE', async (t) => {
  const { base } = await start(t, { setupCode: 'MYCODE2345AB' });
  const outside = { 'cf-connecting-ip': '203.0.113.7' };
  const r = await call(base, 'POST', '/api/setup', { body: { user: 'Anna', password: 'una password lunga', setupCode: 'mycode2345ab' }, headers: outside });
  assert.equal(r.status, 200);
});

test('setup codes: 12 letters and digits without look-alikes', () => {
  const code = makeSetupCode();
  assert.match(code, /^[A-HJ-NP-Z2-9]{12}$/);
  assert.notEqual(code, makeSetupCode());
  assert.equal(sameSetupCode(' ' + code.toLowerCase() + ' ', code), true);
  assert.equal(sameSetupCode(code.slice(1), code), false);
  assert.equal(sameSetupCode('', ''), false);
});
