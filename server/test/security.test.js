import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { mkdtemp, rm, readFile, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createServer } from '../src/server.js';
import { hashPassword, verifyPassword, needsRehash, passwordProblem } from '../src/password.js';
import { lockout } from '../src/limit.js';
import { cbor } from '../src/webauthn.js';

const PASSWORD = 'una password lunga';

async function start(t) {
  const dir = await mkdtemp(path.join(tmpdir(), 'sw-sec-'));
  const app = await createServer({ dataDir: dir });
  await new Promise((r) => app.server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${app.server.address().port}`;
  t.after(async () => {
    await new Promise((r) => app.server.close(r));
    await rm(dir, { recursive: true, force: true });
  });
  return { ...app, base, dir };
}

async function call(base, method, pathname, { token, body, headers = {} } = {}) {
  const res = await fetch(base + pathname, {
    method,
    headers: { ...(token ? { authorization: `Bearer ${token}` } : {}), ...(body ? { 'content-type': 'application/json' } : {}), ...headers },
    body: body ? JSON.stringify(body) : undefined,
  });
  const type = res.headers.get('content-type') ?? '';
  return { status: res.status, headers: res.headers, json: type.includes('json') ? await res.json() : null };
}

async function setup(base) {
  const r = await call(base, 'POST', '/api/setup', { body: { user: 'Anna', password: PASSWORD, device: 'Test' } });
  assert.equal(r.status, 200);
  return r.json.token;
}

// ---------- a fake authenticator, the way a phone or Windows Hello answers ----------

function encode(value) {
  const head = (major, n) => {
    if (n < 24) return Buffer.from([(major << 5) | n]);
    if (n < 256) return Buffer.from([(major << 5) | 24, n]);
    const b = Buffer.alloc(3);
    b[0] = (major << 5) | 25;
    b.writeUInt16BE(n, 1);
    return b;
  };
  if (typeof value === 'number') return value >= 0 ? head(0, value) : head(1, -1 - value);
  if (Buffer.isBuffer(value)) return Buffer.concat([head(2, value.length), value]);
  if (typeof value === 'string') return Buffer.concat([head(3, Buffer.byteLength(value)), Buffer.from(value)]);
  if (value instanceof Map) return Buffer.concat([head(5, value.size), ...[...value].flatMap(([k, v]) => [encode(k), encode(v)])]);
  throw new Error('not encodable');
}

const sha = (data) => crypto.createHash('sha256').update(data).digest();
const b64 = (data) => Buffer.from(data).toString('base64url');

function authenticator() {
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'P-256' });
  const jwk = publicKey.export({ format: 'jwk' });
  const id = crypto.randomBytes(32);
  let counter = 0;
  const cose = encode(new Map([[1, 2], [3, -7], [-1, 1], [-2, Buffer.from(jwk.x, 'base64url')], [-3, Buffer.from(jwk.y, 'base64url')]]));
  const flags = 0x01 | 0x04;
  const data = (rpId, extra = Buffer.alloc(0), f = flags) => {
    const count = Buffer.alloc(4);
    count.writeUInt32BE(counter);
    return Buffer.concat([sha(rpId), Buffer.from([f]), count, extra]);
  };
  return {
    id: b64(id),
    create(options, origin) {
      const clientDataJSON = Buffer.from(JSON.stringify({ type: 'webauthn.create', challenge: options.challenge, origin }));
      const length = Buffer.alloc(2);
      length.writeUInt16BE(id.length);
      const authData = data(options.rp.id, Buffer.concat([Buffer.alloc(16), length, id, cose]), flags | 0x40);
      const attestationObject = encode(new Map([['fmt', 'none'], ['attStmt', new Map()], ['authData', authData]]));
      return { id: b64(id), response: { clientDataJSON: b64(clientDataJSON), attestationObject: b64(attestationObject) } };
    },
    get(options, origin, { userHandle, f, counterStep = 0 } = {}) {
      counter += counterStep;
      const clientDataJSON = Buffer.from(JSON.stringify({ type: 'webauthn.get', challenge: options.challenge, origin }));
      const authenticatorData = data(options.rpId, Buffer.alloc(0), f ?? flags);
      const signature = crypto.sign('sha256', Buffer.concat([authenticatorData, sha(clientDataJSON)]), privateKey);
      return {
        id: b64(id),
        response: { clientDataJSON: b64(clientDataJSON), authenticatorData: b64(authenticatorData), signature: b64(signature), userHandle },
      };
    },
  };
}

// ---------- tests ----------

test('passwords: slow self-describing hash, policy, old hashes replaced', async () => {
  const stored = await hashPassword('Caffè lungo al bar');
  assert.match(stored, /^\$scrypt\$ln=15,r=8,p=1\$/);
  assert.equal(await verifyPassword('Caffè lungo al bar', stored), true);
  // The same text with é written as e + accent.
  assert.equal(await verifyPassword('Caffè lungo al bar', stored), true);
  assert.equal(await verifyPassword('caffè lungo al bar', stored), false);
  assert.equal(await verifyPassword('qualsiasi', null), false);
  assert.equal(needsRehash(stored), false);
  assert.match(passwordProblem('corta', 'x'), /almeno 10/);
  assert.match(passwordProblem('Password123!', 'x'), /facile/);
  assert.match(passwordProblem('aaaaaaaaaaaa', 'x'), /facile/);
  assert.match(passwordProblem('anna.2026.2026', 'Anna'), /facile/);
  assert.equal(passwordProblem('giacca blu sul divano', 'Anna'), null);
});

test('an account of 0.3 still signs in, and its hash is made new', async (t) => {
  const { dir, server } = await start(t);
  await new Promise((r) => server.close(r));
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync('vecchia8', salt, 32, { N: 16384, r: 8, p: 1 }).toString('hex');
  await writeFile(path.join(dir, 'auth.json'), JSON.stringify({ user: 'Anna', password: { salt, hash }, tokens: [] }));
  const again = await createServer({ dataDir: dir });
  await new Promise((r) => again.server.listen(0, '127.0.0.1', r));
  t.after(() => new Promise((r) => again.server.close(r)));
  const url = `http://127.0.0.1:${again.server.address().port}`;
  assert.equal((await call(url, 'POST', '/api/login', { body: { user: 'anna', password: 'vecchia8' } })).status, 200);
  const saved = JSON.parse(await readFile(path.join(dir, 'auth.json'), 'utf8'));
  assert.match(saved.password, /^\$scrypt\$ln=15/);
  assert.equal((await call(url, 'POST', '/api/login', { body: { user: 'anna', password: 'vecchia8' } })).status, 200);
  // It gets the id that passkeys carry for the account too.
  assert.match(again.auth.userHandle, /^[\w-]{22}$/);
  assert.equal(JSON.parse(await readFile(path.join(dir, 'auth.json'), 'utf8')).userHandle, again.auth.userHandle);
});

test('nothing in auth.json signs in: hashes only', async (t) => {
  const { base, dir } = await start(t);
  const token = await setup(base);
  const link = await call(base, 'POST', '/api/link', { token });
  const text = await readFile(path.join(dir, 'auth.json'), 'utf8');
  assert.equal(text.includes(PASSWORD), false);
  assert.equal(text.includes(token), false);
  assert.equal(text.includes(link.json.code), false);
  assert.equal(text.includes(link.json.code.replace(/-/g, '')), false);
});

test('wrong passwords pause the address, also for the right one', async (t) => {
  const { base } = await start(t);
  await setup(base);
  const outside = { 'x-forwarded-for': '198.51.100.20' };
  for (let i = 0; i < 6; i++) {
    const r = await call(base, 'POST', '/api/login', { body: { user: 'Anna', password: 'sbagliata-' + i }, headers: outside });
    assert.equal(r.status, 401);
  }
  const blocked = await call(base, 'POST', '/api/login', { body: { user: 'Anna', password: PASSWORD }, headers: outside });
  assert.equal(blocked.status, 429);
  assert.ok(Number(blocked.headers.get('retry-after')) > 0);
  // Another address is not paused.
  assert.equal((await call(base, 'POST', '/api/login', { body: { user: 'Anna', password: PASSWORD }, headers: { 'x-forwarded-for': '198.51.100.21' } })).status, 200);
});

test('a burst of tries is counted before the answers come back', async (t) => {
  const { base } = await start(t);
  await setup(base);
  const outside = { 'x-forwarded-for': '198.51.100.30' };
  const answers = await Promise.all(Array.from({ length: 12 }, (_, i) =>
    call(base, 'POST', '/api/login', { body: { user: 'Anna', password: 'tentativo-' + i }, headers: outside })));
  assert.ok(answers.filter((a) => a.status === 429).length >= 6);
});

test('the lockout doubles, forgets after a right answer, and gives back a try', () => {
  let now = 0;
  const l = lockout({ free: 2, baseMs: 1000, maxMs: 4000, now: () => now });
  l.attempt('a');
  l.attempt('a');
  assert.equal(l.wait('a'), 0);
  l.attempt('a');
  assert.equal(l.wait('a'), 1000);
  l.attempt('a');
  assert.equal(l.wait('a'), 2000);
  l.attempt('a');
  l.attempt('a');
  assert.equal(l.wait('a'), 4000);
  l.reset('a');
  assert.equal(l.wait('a'), 0);
  const back = l.attempt('b');
  l.attempt('b');
  l.attempt('b');
  assert.equal(l.wait('b'), 1000);
  back();
  assert.equal(l.wait('b'), 0);
});

test('requests from other sites are refused, login included', async (t) => {
  const { base } = await start(t);
  await setup(base);
  const evil = { origin: 'https://evil.example', 'sec-fetch-site': 'cross-site' };
  assert.equal((await call(base, 'POST', '/api/login', { body: { user: 'Anna', password: PASSWORD }, headers: evil })).status, 403);
  assert.equal((await call(base, 'POST', '/api/login', { body: { user: 'Anna', password: PASSWORD }, headers: { origin: 'https://evil.example' } })).status, 403);
  assert.equal((await call(base, 'POST', '/api/login', { body: { user: 'Anna', password: PASSWORD }, headers: { 'sec-fetch-site': 'same-site' } })).status, 403);
  const own = { origin: base, 'sec-fetch-site': 'same-origin' };
  assert.equal((await call(base, 'POST', '/api/login', { body: { user: 'Anna', password: PASSWORD }, headers: own })).status, 200);
});

test('over https the cookie is __Host- and Secure, and HSTS is on', async (t) => {
  const { base } = await start(t);
  const r = await call(base, 'POST', '/api/setup', { body: { user: 'Anna', password: PASSWORD }, headers: { 'x-forwarded-proto': 'https' } });
  assert.match(r.headers.get('set-cookie'), /^__Host-sw_session=[\w-]+; Path=\/; HttpOnly; Secure; SameSite=Strict; Max-Age=7776000$/);
  assert.match(r.headers.get('strict-transport-security'), /max-age=31536000/);
  const cookie = r.headers.get('set-cookie').split(';')[0];
  assert.equal((await call(base, 'GET', '/api/closet', { headers: { cookie } })).status, 200);
  assert.equal((await call(base, 'GET', '/api/status')).headers.get('x-content-type-options'), 'nosniff');
});

test('a token unused for 90 days stops working; using it keeps it alive', async (t) => {
  const { base, auth } = await start(t);
  const token = await setup(base);
  const device = auth.data.tokens[0];
  device.seen = new Date(Date.now() - 89 * 86_400_000).toISOString();
  assert.equal((await call(base, 'GET', '/api/closet', { token })).status, 200);
  assert.ok(Date.now() - Date.parse(device.seen) < 60_000);
  device.seen = new Date(Date.now() - 91 * 86_400_000).toISOString();
  assert.equal((await call(base, 'GET', '/api/closet', { token })).status, 401);
  assert.equal(auth.data.tokens.length, 0);
});

test('a code connects one new device, once, for ten minutes', async (t) => {
  const { base, auth } = await start(t);
  const token = await setup(base);
  assert.equal((await call(base, 'POST', '/api/link')).status, 401);
  const link = await call(base, 'POST', '/api/link', { token });
  assert.match(link.json.code, /^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$/);
  assert.equal((await call(base, 'POST', '/api/link/redeem', { body: { code: 'AAAA-BBBB-CCCC' } })).status, 401);
  const used = await call(base, 'POST', '/api/link/redeem', { body: { code: link.json.code.toLowerCase().replace(/-/g, ' '), device: 'iPad' } });
  assert.equal(used.status, 200);
  assert.equal((await call(base, 'GET', '/api/closet', { token: used.json.token })).status, 200);
  assert.equal((await call(base, 'POST', '/api/link/redeem', { body: { code: link.json.code } })).status, 401);
  const devices = await call(base, 'GET', '/api/devices', { token });
  assert.equal(devices.json.devices.find((d) => d.name === 'iPad').via, 'codice');
  // Expired.
  const late = await call(base, 'POST', '/api/link', { token });
  auth.data.link.expires = Date.now() - 1;
  assert.equal((await call(base, 'POST', '/api/link/redeem', { body: { code: late.json.code } })).status, 401);
  // A new password drops the code in waiting.
  const waiting = await call(base, 'POST', '/api/link', { token });
  await call(base, 'POST', '/api/account', { token, body: { current: PASSWORD, next: 'un’altra frase lunga' } });
  assert.equal((await call(base, 'POST', '/api/link/redeem', { body: { code: waiting.json.code } })).status, 401);
});

test('passkeys: add one signed in, then sign in with it', async (t) => {
  const { base, auth } = await start(t);
  const token = await setup(base);
  const key = authenticator();
  const options = await call(base, 'POST', '/api/passkeys/options', { token });
  assert.equal(options.status, 200);
  assert.equal(options.json.rp.id, '127.0.0.1');
  assert.equal(options.json.authenticatorSelection.userVerification, 'required');
  const created = await call(base, 'POST', '/api/passkeys', { token, body: { ...key.create(options.json, base), name: 'iPhone di Anna' } });
  assert.equal(created.status, 200, JSON.stringify(created.json));
  assert.equal(created.json.passkeys[0].name, 'iPhone di Anna');
  assert.equal((await call(base, 'GET', '/api/status')).json.passkeys, true);
  // Nothing secret stored: a public key.
  assert.match(auth.data.passkeys[0].publicKey, /BEGIN PUBLIC KEY/);

  const ask = await call(base, 'POST', '/api/passkey/options', { body: {} });
  const answer = key.get(ask.json, base, { userHandle: auth.userHandle });
  const login = await call(base, 'POST', '/api/passkey/login', { body: { ...answer, device: 'Brave' } });
  assert.equal(login.status, 200, JSON.stringify(login.json));
  assert.equal((await call(base, 'GET', '/api/closet', { token: login.json.token })).status, 200);
  assert.ok(auth.data.passkeys[0].used);
  // The same answer again: its challenge is used up.
  assert.equal((await call(base, 'POST', '/api/passkey/login', { body: answer })).status, 400);
});

test('passkeys: wrong site, no verification, bad signature, copied key are refused', async (t) => {
  const { base, auth } = await start(t);
  const token = await setup(base);
  const key = authenticator();
  const options = await call(base, 'POST', '/api/passkeys/options', { token });
  // Made on another site's page.
  assert.equal((await call(base, 'POST', '/api/passkeys', { token, body: key.create(options.json, 'https://evil.example') })).status, 400);
  const fresh = await call(base, 'POST', '/api/passkeys/options', { token });
  assert.equal((await call(base, 'POST', '/api/passkeys', { token, body: key.create(fresh.json, base) })).status, 200);

  const tryWith = async (make) => {
    const ask = await call(base, 'POST', '/api/passkey/options', { body: {} });
    return call(base, 'POST', '/api/passkey/login', { body: make(ask.json) });
  };
  assert.equal((await tryWith((o) => key.get(o, 'https://evil.example'))).status, 401);
  assert.equal((await tryWith((o) => key.get({ ...o, rpId: 'evil.example' }, base))).status, 401);
  assert.equal((await tryWith((o) => key.get(o, base, { f: 0x01 }))).status, 401);
  assert.equal((await tryWith((o) => {
    const a = key.get(o, base);
    const sig = Buffer.from(a.response.signature, 'base64url');
    sig[sig.length - 1] ^= 1;
    a.response.signature = b64(sig);
    return a;
  })).status, 401);
  assert.equal((await tryWith((o) => ({ ...key.get(o, base), id: b64(crypto.randomBytes(32)) }))).status, 401);
  // A challenge made up by the caller.
  assert.equal((await call(base, 'POST', '/api/passkey/login', { body: key.get({ challenge: b64(crypto.randomBytes(32)), rpId: '127.0.0.1' }, base) })).status, 400);
  // Counter: once it moved, going back means a copy.
  assert.equal((await tryWith((o) => key.get(o, base, { counterStep: 5 }))).status, 200);
  assert.equal((await tryWith((o) => key.get(o, base, { counterStep: -2 }))).status, 401);
  // Removed from the site: it no longer signs in.
  const id = auth.data.passkeys[0].id;
  assert.equal((await call(base, 'DELETE', `/api/passkeys/${id}`, { token })).status, 200);
  assert.equal((await tryWith((o) => key.get(o, base, { counterStep: 10 }))).status, 401);
});

test('passkeys need https or this computer', async (t) => {
  const { base } = await start(t);
  const token = await setup(base);
  const r = await call(base, 'POST', '/api/passkey/options', { body: {}, headers: { 'x-forwarded-host': '192.168.1.10:30320' } });
  assert.equal(r.status, 400);
  const ok = await call(base, 'POST', '/api/passkeys/options', { token, headers: { 'x-forwarded-host': 'shadowwear.example.org', 'x-forwarded-proto': 'https' } });
  assert.equal(ok.json.rp.id, 'shadowwear.example.org');
  // Behind a tunnel that does not pass the scheme on: the name is enough, the answer proves https.
  const tunnel = await call(base, 'POST', '/api/passkey/options', { body: {}, headers: { 'x-forwarded-host': 'shadowwear.example.org' } });
  assert.equal(tunnel.json.rpId, 'shadowwear.example.org');
  // An answer from an http page of that name is refused.
  const key = authenticator();
  const made = await call(base, 'POST', '/api/passkeys/options', { token, headers: { 'x-forwarded-host': 'shadowwear.example.org' } });
  const plain = await call(base, 'POST', '/api/passkeys', { token, body: key.create(made.json, 'http://shadowwear.example.org'), headers: { 'x-forwarded-host': 'shadowwear.example.org' } });
  assert.equal(plain.status, 400);
  const secure = await call(base, 'POST', '/api/passkeys/options', { token, headers: { 'x-forwarded-host': 'shadowwear.example.org' } });
  const good = await call(base, 'POST', '/api/passkeys', { token, body: key.create(secure.json, 'https://shadowwear.example.org'), headers: { 'x-forwarded-host': 'shadowwear.example.org' } });
  assert.equal(good.status, 200);
  // Cloudflare's way of saying https.
  const cf = await call(base, 'POST', '/api/login', { body: { user: 'Anna', password: PASSWORD }, headers: { 'cf-visitor': '{"scheme":"https"}' } });
  assert.match(cf.headers.get('set-cookie'), /^__Host-sw_session=/);
});

test('the CBOR reader refuses what it cannot read', () => {
  assert.deepEqual(cbor(Buffer.from([0x83, 0x01, 0x20, 0x41, 0xff])).value, [1, -1, Buffer.from([0xff])]);
  assert.throws(() => cbor(Buffer.from([0x5f])));
  assert.throws(() => cbor(Buffer.from([0x45, 0x01])));
  assert.throws(() => cbor(Buffer.from([0x9f])));
});
