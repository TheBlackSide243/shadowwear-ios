// ShadowWear server: keeps the closet of the iPhone app in sync between devices, serves the web
// site to open it from a computer, and asks the house's Ollama to describe pieces.
// Only Node's own modules: it runs on the plain node image, no install step.

import http from 'node:http';
import { promises as fs, createReadStream } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Store, isID, isPhotoName, isoNow } from './store.js';
import { Auth, TOKEN_DAYS } from './auth.js';
import { Ollama } from './ollama.js';
import { BusyError, warmUp } from './password.js';
import { lockout, budget } from './limit.js';
import { ALGORITHMS, PasskeyError, challenges, originOK, verifyAssertion, verifyRegistration } from './webauthn.js';

const here = path.dirname(fileURLToPath(import.meta.url));
export const VERSION = '0.5.0';

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.webmanifest': 'application/manifest+json',
};

class HttpError extends Error {
  constructor(status, message, headers = {}) {
    super(message);
    this.status = status;
    this.headers = headers;
  }
}

function tooMany(ms) {
  return new HttpError(429, 'Troppi tentativi sbagliati: aspetta qualche minuto e riprova.', { 'retry-after': String(Math.ceil(ms / 1000)) });
}

function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > limit) {
        reject(new HttpError(413, 'Troppo grande.'));
        req.destroy();
      } else chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

async function readJSON(req, limit = 20 * 1024 * 1024) {
  const body = await readBody(req, limit);
  if (!body.length) return {};
  try {
    return JSON.parse(body.toString('utf8'));
  } catch {
    throw new HttpError(400, 'JSON non valido.');
  }
}

function send(res, status, body, headers = {}) {
  const json = typeof body !== 'string' && !Buffer.isBuffer(body);
  res.writeHead(status, {
    'content-type': json ? 'application/json; charset=utf-8' : 'text/plain; charset=utf-8',
    'cache-control': 'no-store',
    ...headers,
  });
  res.end(json ? JSON.stringify(body) : body);
}

function cookies(req) {
  const out = {};
  for (const part of (req.headers.cookie ?? '').split(';')) {
    const i = part.indexOf('=');
    if (i > 0) out[part.slice(0, i).trim()] = decodeURIComponent(part.slice(i + 1).trim());
  }
  return out;
}

/** Loopback, private (10/8, 172.16/12, 192.168/16), link-local and IPv6 ULA addresses. */
export function isPrivate(ip) {
  const a = String(ip || '').replace(/^::ffff:/, '');
  return /^(127\.|10\.|192\.168\.|169\.254\.|172\.(1[6-9]|2\d|3[01])\.)/.test(a) || a === '::1' || /^f[cd]/i.test(a) || /^fe80:/i.test(a);
}

/**
 * The address of whoever is asking. Behind a proxy in the house (Nginx Proxy Manager, the
 * Cloudflare tunnel) the real one is in the headers; they are trusted only from a home address.
 */
export function clientAddress(req) {
  const peer = req.socket.remoteAddress ?? '?';
  if (!isPrivate(peer)) return peer;
  const forwarded = req.headers['cf-connecting-ip'] || String(req.headers['x-forwarded-for'] || '').split(',')[0].trim() || req.headers['x-real-ip'];
  return forwarded || peer;
}

/** Whether the page was asked for over https: directly, or through a proxy in the house. */
export function isHttps(req) {
  if (req.socket.encrypted) return true;
  if (!isPrivate(req.socket.remoteAddress)) return false;
  if (String(req.headers['x-forwarded-proto'] || '').split(',')[0].trim().toLowerCase() === 'https') return true;
  // The Cloudflare tunnel says it this way.
  return /"scheme"\s*:\s*"https"/.test(String(req.headers['cf-visitor'] || ''));
}

/** The host the browser asked for (behind a proxy in the house: the one it passes on). */
export function requestHost(req) {
  const forwarded = isPrivate(req.socket.remoteAddress) ? String(req.headers['x-forwarded-host'] || '').split(',')[0].trim() : '';
  return (forwarded || String(req.headers.host || '')).toLowerCase();
}

/**
 * Whether a request that changes something comes from a page of this server. Browsers say where a
 * request comes from (Sec-Fetch-Site, Origin) and no page can fake it; the iPhone app sends neither.
 * Also stops another site from signing a visitor in to an account it chose (login CSRF).
 */
export function fromThisSite(req) {
  const site = req.headers['sec-fetch-site'];
  if (site && site !== 'same-origin' && site !== 'none') return false;
  const origin = req.headers.origin;
  if (origin === undefined) return true;
  try {
    return new URL(origin).host === requestHost(req);
  } catch {
    return false;
  }
}

// Over https the cookie is __Host-: the browser then keeps it to this exact host, https only.
const COOKIE_HTTPS = '__Host-sw_session';
const COOKIE_HTTP = 'sw_session';

function sessionCookie(req, token, maxAge = TOKEN_DAYS * 86_400) {
  return isHttps(req)
    ? `${COOKIE_HTTPS}=${token}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=${maxAge}`
    : `${COOKIE_HTTP}=${token}; Path=/; HttpOnly; SameSite=Strict; Max-Age=${maxAge}`;
}

export async function createServer({ dataDir, webDir = path.join(here, '..', 'web'), ollamaURL = '', fetcher } = {}) {
  await fs.mkdir(dataDir, { recursive: true });
  const store = await new Store(dataDir).open();
  const auth = await new Auth(dataDir).open();
  const ollama = new Ollama(ollamaURL, fetcher);
  const settingsFile = path.join(dataDir, 'settings.json');
  let settings = { aiModel: '', language: 'it' };
  try {
    settings = { ...settings, ...JSON.parse(await fs.readFile(settingsFile, 'utf8')) };
  } catch {
    // First start: defaults.
  }

  async function saveSettings() {
    await fs.writeFile(settingsFile, JSON.stringify(settings, null, 1));
  }

  /** The device or browser behind the request: a Bearer token (app) or the session cookie (web). */
  function caller(req) {
    const header = req.headers.authorization ?? '';
    if (header.startsWith('Bearer ')) return { device: auth.find(header.slice(7)), web: false };
    const jar = cookies(req);
    const token = jar[COOKIE_HTTPS] ?? jar[COOKIE_HTTP];
    return { device: auth.find(token), web: true, token };
  }

  // Wrong passwords and codes: per address, 5 free, then a pause of 1 minute that doubles up to an
  // hour. From the internet, all addresses together also count for the account (20 free, up to
  // 15 minutes), so many machines cannot guess side by side; from home that one never blocks.
  const tries = lockout({ free: 5, baseMs: 60_000, maxMs: 3_600_000 });
  const accountTries = lockout({ free: 20, baseMs: 60_000, maxMs: 15 * 60_000 });
  // And at most 30 sign-in requests a minute per address, right or wrong.
  const requests = budget({ max: 30, windowMs: 60_000 });
  const ceremonies = challenges();

  /** Before any sign-in: the address within its budget and not paused. */
  function gate(req) {
    const from = clientAddress(req);
    if (!requests.take(from)) throw tooMany(60_000);
    const wait = tries.wait(from);
    if (wait) throw tooMany(wait);
    const outside = !isPrivate(from);
    if (outside && accountTries.wait('account')) throw tooMany(accountTries.wait('account'));
    return {
      from,
      /** Counts a try; the function it returns says how it went (true: right). */
      attempt() {
        const back = [tries.attempt(from), outside ? accountTries.attempt('account') : () => {}];
        return (right) => {
          if (right === true) {
            tries.reset(from);
            if (outside) accountTries.reset('account');
          } else if (right === null) back.forEach((f) => f());
        };
      },
    };
  }

  /** The password, checked under the lockout; throws 401 when wrong. */
  async function checkPassword(req, user, password) {
    const done = gate(req).attempt();
    let right;
    try {
      right = await auth.check(user, password);
    } catch (error) {
      done(null);
      if (error instanceof BusyError) throw new HttpError(503, 'Il server è occupato: riprova tra poco.');
      throw error;
    }
    done(right);
    return right;
  }

  async function login(req, res, user, password, name) {
    if (!(await checkPassword(req, user, password))) throw new HttpError(401, 'Nome utente o password sbagliati.');
    const token = await auth.issue(name, 'password');
    send(res, 200, { token }, { 'set-cookie': sessionCookie(req, token) });
  }

  /**
   * The site name of a passkey for this request: the host without its port. Passkeys need a name,
   * not an address like 192.168.1.10 (only this computer is allowed by number). That the page is
   * https is checked by the browser and again on the answer (originOK), whatever the proxy says.
   */
  function passkeySite(req) {
    const host = requestHost(req);
    let site = null;
    try {
      site = new URL(`https://${host}`).hostname;
    } catch {
      // Not a host at all.
    }
    const loopback = site === 'localhost' || site === '127.0.0.1' || site === '[::1]';
    const number = /^\d+\.\d+\.\d+\.\d+$/.test(site ?? '') || site?.startsWith('[');
    if (!site || (number && !loopback)) throw new HttpError(400, 'Le passkey funzionano solo aprendo il sito del server con il suo dominio in https.');
    return { host, site };
  }

  async function staticFile(res, name) {
    const file = path.join(webDir, name);
    if (!file.startsWith(webDir)) throw new HttpError(404, 'Non trovato.');
    try {
      const body = await fs.readFile(file);
      res.writeHead(200, {
        'content-type': TYPES[path.extname(file)] ?? 'application/octet-stream',
        'cache-control': name === 'index.html' ? 'no-cache' : 'public, max-age=300',
        'content-security-policy': "default-src 'self'; img-src 'self' blob: data:; style-src 'self'; script-src 'self'; frame-ancestors 'none'",
        'x-content-type-options': 'nosniff',
        'referrer-policy': 'no-referrer',
      });
      res.end(body);
    } catch {
      throw new HttpError(404, 'Non trovato.');
    }
  }

  async function photo(req, res, name) {
    const file = store.photoPath(name);
    if (!file) throw new HttpError(404, 'Foto non trovata.');
    let stat;
    try {
      stat = await fs.stat(file);
    } catch {
      throw new HttpError(404, 'Foto non trovata.');
    }
    const etag = `"${stat.size.toString(16)}-${Math.floor(stat.mtimeMs).toString(16)}"`;
    if (req.headers['if-none-match'] === etag) {
      res.writeHead(304, { etag });
      return res.end();
    }
    res.writeHead(200, {
      'content-type': name.endsWith('.png') ? 'image/png' : 'image/jpeg',
      'content-length': stat.size,
      'cache-control': 'private, max-age=0, must-revalidate',
      etag,
    });
    createReadStream(file).pipe(res);
  }

  async function handle(req, res) {
    const url = new URL(req.url, 'http://local');
    const parts = url.pathname.split('/').filter(Boolean);
    const method = req.method;

    // The web site.
    if (parts[0] !== 'api') {
      if (method !== 'GET' && method !== 'HEAD') throw new HttpError(405, 'Metodo non ammesso.');
      const name = parts.length === 0 ? 'index.html' : parts.join('/');
      if (!/^[\w.-]+$/.test(name)) return staticFile(res, 'index.html');
      return staticFile(res, name);
    }

    const route = parts.slice(1);
    // Nothing that changes things from a page of another site, signed in or not.
    if (method !== 'GET' && method !== 'HEAD' && !fromThisSite(req)) throw new HttpError(403, 'Richiesta non ammessa.');

    // Open to anyone: whether the server is set up, the first account (from the house only), the
    // sign-ins (password, passkey, code from another device).
    if (route[0] === 'status' && method === 'GET') {
      const who = caller(req);
      return send(res, 200, {
        app: 'shadowwear',
        version: VERSION,
        configured: auth.configured,
        signedIn: Boolean(who.device),
        passkeys: auth.data.passkeys.length > 0,
        ai: { available: ollama.configured, model: settings.aiModel || null },
      });
    }
    if (route[0] === 'setup' && method === 'POST') {
      if (auth.configured) throw new HttpError(409, 'Il server ha già un account.');
      // Until there is an account, anyone could choose it: not from the internet.
      if (!isPrivate(clientAddress(req))) throw new HttpError(403, "Il primo accesso si crea dalla rete di casa: apri il server con l'indirizzo della NAS.");
      gate(req);
      const body = await readJSON(req, 10_000);
      try {
        await auth.setAccount(body.user, body.password);
      } catch (error) {
        throw new HttpError(error instanceof BusyError ? 503 : 400, error instanceof BusyError ? 'Il server è occupato: riprova tra poco.' : error.message);
      }
      const token = await auth.issue(body.device || 'Browser', 'password');
      return send(res, 200, { token }, { 'set-cookie': sessionCookie(req, token) });
    }
    if (route[0] === 'login' && method === 'POST') {
      const body = await readJSON(req, 10_000);
      return login(req, res, body.user, body.password, body.device || 'Browser');
    }
    // Sign-in with a passkey: first a challenge, then the signed answer.
    if (route[0] === 'passkey' && route[1] === 'options' && method === 'POST') {
      gate(req);
      const { site } = passkeySite(req);
      return send(res, 200, {
        challenge: ceremonies.make('get'),
        rpId: site,
        timeout: 300_000,
        userVerification: 'required',
        allowCredentials: [],
      });
    }
    if (route[0] === 'passkey' && route[1] === 'login' && method === 'POST') {
      gate(req);
      const body = await readJSON(req, 20_000);
      const { host } = passkeySite(req);
      const response = body.response ?? {};
      const ceremony = ceremonies.take(response.clientDataJSON, 'get');
      if (!ceremony) throw new HttpError(400, 'Richiesta della passkey scaduta: riprova.');
      const passkey = auth.passkey(body.id);
      const handle = typeof response.userHandle === 'string' ? response.userHandle : null;
      if (!passkey || (handle && handle !== auth.userHandle)) throw new HttpError(401, 'Questa passkey non è più del server: accedi con la password.');
      let count;
      try {
        count = verifyAssertion(response, passkey, { challenge: ceremony.challenge, host });
      } catch (error) {
        if (error instanceof PasskeyError) throw new HttpError(401, error.message);
        throw error;
      }
      await auth.usedPasskey(passkey, count);
      const token = await auth.issue(body.device || 'Browser', 'passkey');
      return send(res, 200, { token }, { 'set-cookie': sessionCookie(req, token) });
    }
    // A new device with the code shown by one already signed in (the site: Collega un dispositivo).
    if (route[0] === 'link' && route[1] === 'redeem' && method === 'POST') {
      const done = gate(req).attempt();
      const body = await readJSON(req, 10_000);
      const right = await auth.useLink(body.code);
      done(right);
      if (!right) throw new HttpError(401, 'Codice sbagliato o scaduto: creane uno nuovo dal sito.');
      const token = await auth.issue(body.device || 'Dispositivo', 'codice');
      return send(res, 200, { token });
    }

    // Everything else needs a device token or the session cookie.
    const who = caller(req);
    if (!who.device) throw new HttpError(401, 'Accedi prima.');
    // A page on another site cannot set this header: no cross-site requests with the cookie.
    if (who.web && method !== 'GET' && req.headers['x-shadowwear'] !== 'web') throw new HttpError(403, 'Richiesta non ammessa.');

    if (route[0] === 'logout' && method === 'POST') {
      await auth.revoke(who.device.id);
      return send(res, 200, { ok: true }, { 'set-cookie': sessionCookie(req, '', 0) });
    }

    if (route[0] === 'closet' && method === 'GET') {
      return send(res, 200, {
        items: store.list('items'),
        outfits: store.list('outfits'),
        wears: store.list('wears'),
        photos: await store.photoNames(),
      });
    }

    if (route[0] === 'sync' && route[1] === 'compare' && method === 'POST') {
      const manifest = await readJSON(req);
      const answer = store.compare(manifest);
      await store.save();
      answer.photos = await store.photoNames();
      answer.serverTime = isoNow();
      return send(res, 200, answer);
    }
    if (route[0] === 'sync' && route[1] === 'push' && method === 'POST') {
      const changed = store.push(await readJSON(req));
      await store.save();
      return send(res, 200, { changed });
    }

    // One record at a time, for the web site.
    const kinds = { items: 'items', outfits: 'outfits', wears: 'wears', wishes: 'wishes' };
    if (kinds[route[0]] && route[1]) {
      const kind = kinds[route[0]];
      const id = route[1];
      if (!isID(id)) throw new HttpError(400, 'Id non valido.');
      if (method === 'PUT') {
        const record = await readJSON(req, 1_000_000);
        record.id = id;
        if (kind !== 'wears') record.updated = isoNow();
        if (kind !== 'wears' && !record.created) record.created = record.updated;
        if (!store.put(kind, record)) throw new HttpError(409, 'Cambiato nel frattempo da un altro dispositivo.');
        await store.save();
        return send(res, 200, store.get(kind, id));
      }
      if (method === 'DELETE') {
        store.remove(kind, id);
        await store.save();
        return send(res, 200, { ok: true });
      }
    }

    if (route[0] === 'photos' && route[1]) {
      const name = route[1];
      if (!isPhotoName(name)) throw new HttpError(400, 'Nome della foto non valido.');
      if (method === 'GET') return photo(req, res, name);
      if (method === 'PUT') {
        const bytes = await readBody(req, 40 * 1024 * 1024);
        const png = bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
        const jpeg = bytes[0] === 0xff && bytes[1] === 0xd8;
        if ((name.endsWith('.png') && !png) || (name.endsWith('.jpg') && !jpeg)) throw new HttpError(400, 'Non è un\'immagine.');
        await store.writePhoto(name, bytes);
        return send(res, 200, { ok: true });
      }
    }

    if (route[0] === 'ai') {
      if (!ollama.configured) throw new HttpError(503, 'Il server non ha Ollama: imposta OLLAMA_URL.');
      if (route[1] === 'models' && method === 'GET') {
        try {
          return send(res, 200, { models: await ollama.models(), model: settings.aiModel || null });
        } catch (error) {
          throw new HttpError(502, `Ollama non risponde: ${error.message}`);
        }
      }
      // Whatever the app asks (tags, the stylist, a selfie, ideas around a piece): the app writes
      // the question, the server only passes it to its model, with a photo when there is one.
      if (route[1] === 'chat' && method === 'POST') {
        if (!settings.aiModel) throw new HttpError(503, 'Nessun modello scelto: sceglilo nelle impostazioni del sito.');
        const body = await readJSON(req, 30 * 1024 * 1024);
        const prompt = typeof body.prompt === 'string' ? body.prompt.slice(0, 60_000) : '';
        if (!prompt) throw new HttpError(400, 'Manca la domanda.');
        const system = typeof body.system === 'string' ? body.system.slice(0, 20_000) : '';
        let image = null;
        if (typeof body.image === 'string' && body.image) {
          image = Buffer.from(body.image, 'base64');
          if (image.length < 100) throw new HttpError(400, 'Foto non valida.');
        }
        try {
          const text = await ollama.chat(settings.aiModel, { system, prompt, image, json: body.json === true });
          return send(res, 200, { text });
        } catch (error) {
          throw new HttpError(502, `L'IA non ha risposto: ${error.message}`);
        }
      }
      if (route[1] === 'describe' && method === 'POST') {
        const image = await readBody(req, 40 * 1024 * 1024);
        if (image.length < 100) throw new HttpError(400, 'Manca la foto.');
        try {
          const language = url.searchParams.get('lang') === 'en' ? 'en' : settings.language;
          return send(res, 200, await ollama.describe(settings.aiModel, image, language));
        } catch (error) {
          throw new HttpError(502, `L'IA non ha risposto: ${error.message}`);
        }
      }
    }

    if (route[0] === 'settings') {
      if (method === 'GET') return send(res, 200, settings);
      if (method === 'PUT') {
        const body = await readJSON(req, 10_000);
        if (typeof body.aiModel === 'string') settings.aiModel = body.aiModel.slice(0, 200);
        if (body.language === 'it' || body.language === 'en') settings.language = body.language;
        await saveSettings();
        return send(res, 200, settings);
      }
    }

    if (route[0] === 'devices') {
      if (method === 'GET' && !route[1]) {
        return send(res, 200, { devices: auth.devices().map((d) => ({ ...d, current: d.id === who.device.id })) });
      }
      if (method === 'DELETE' && route[1]) {
        if (!(await auth.revoke(route[1]))) throw new HttpError(404, 'Dispositivo non trovato.');
        return send(res, 200, { ok: true });
      }
    }

    if (route[0] === 'account' && method === 'GET') {
      return send(res, 200, { user: auth.user });
    }
    // New user name and/or password, with the current password.
    if ((route[0] === 'account' || route[0] === 'password') && method === 'POST') {
      const body = await readJSON(req, 10_000);
      if (!(await checkPassword(req, auth.user, body.current))) throw new HttpError(401, 'La password attuale è sbagliata.');
      const user = typeof body.user === 'string' && body.user.trim() && body.user.trim() !== auth.user ? body.user : null;
      const next = typeof body.next === 'string' && body.next ? body.next : null;
      try {
        await auth.setAccount(user, next);
      } catch (error) {
        throw new HttpError(400, error.message);
      }
      // A new password signed every device out: this one gets a new token.
      if (!next) return send(res, 200, { user: auth.user });
      const token = await auth.issue(who.device.name, who.device.via);
      return send(res, 200, { user: auth.user, token }, who.web ? { 'set-cookie': sessionCookie(req, token) } : {});
    }

    // Passkeys of the account: list, add (from the site, signed in), remove.
    if (route[0] === 'passkeys') {
      if (method === 'GET' && !route[1]) return send(res, 200, { passkeys: auth.passkeys() });
      if (method === 'POST' && route[1] === 'options') {
        const { site } = passkeySite(req);
        return send(res, 200, {
          challenge: ceremonies.make('create', { device: who.device.id }),
          rp: { name: 'ShadowWear', id: site },
          user: { id: auth.userHandle, name: auth.user || 'shadowwear', displayName: auth.user || 'ShadowWear' },
          pubKeyCredParams: ALGORITHMS.map((alg) => ({ type: 'public-key', alg })),
          timeout: 300_000,
          attestation: 'none',
          authenticatorSelection: { residentKey: 'required', requireResidentKey: true, userVerification: 'required' },
          excludeCredentials: auth.data.passkeys.filter((p) => p.rpId === site).map((p) => ({ type: 'public-key', id: p.id })),
        });
      }
      if (method === 'POST' && !route[1]) {
        const body = await readJSON(req, 50_000);
        const { host } = passkeySite(req);
        const response = body.response ?? {};
        const ceremony = ceremonies.take(response.clientDataJSON, 'create');
        if (!ceremony || ceremony.device !== who.device.id) throw new HttpError(400, 'Richiesta della passkey scaduta: riprova.');
        try {
          await auth.addPasskey(verifyRegistration(response, { challenge: ceremony.challenge, host }), body.name);
        } catch (error) {
          throw new HttpError(400, error.message);
        }
        return send(res, 200, { passkeys: auth.passkeys() });
      }
      if (method === 'DELETE' && route[1]) {
        if (!(await auth.removePasskey(route[1]))) throw new HttpError(404, 'Passkey non trovata.');
        return send(res, 200, { passkeys: auth.passkeys() });
      }
    }

    // A code (and its QR) to connect another device without typing the password there.
    if (route[0] === 'link' && !route[1]) {
      if (method === 'POST') return send(res, 200, await auth.makeLink());
      if (method === 'DELETE') {
        auth.data.link = null;
        await auth.save();
        return send(res, 200, { ok: true });
      }
    }

    throw new HttpError(404, 'Non trovato.');
  }

  const server = http.createServer((req, res) => {
    res.setHeader('x-content-type-options', 'nosniff');
    res.setHeader('referrer-policy', 'no-referrer');
    res.setHeader('x-frame-options', 'DENY');
    // Over https: the browser keeps to https for this host from now on.
    if (isHttps(req)) res.setHeader('strict-transport-security', 'max-age=31536000');
    handle(req, res).catch((error) => {
      const status = error.status ?? 500;
      if (status === 500) console.error(error);
      if (!res.headersSent) send(res, status, { error: status === 500 ? 'Errore del server.' : error.message }, error.headers ?? {});
      else res.end();
    });
  });
  warmUp();

  // Once a day, photos no piece uses any more (older than a day, so uploads in flight stay).
  const prune = setInterval(() => store.prunePhotos().catch(() => {}), 24 * 3_600_000);
  prune.unref();
  server.on('close', () => clearInterval(prune));

  return { server, store, auth, settings };
}

// Started directly (node src/server.js): listen.
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const port = Number(process.env.PORT || 8080);
  const { server } = await createServer({
    dataDir: process.env.DATA_DIR || path.join(here, '..', 'data'),
    ollamaURL: process.env.OLLAMA_URL || '',
  });
  server.listen(port, () => console.log(`ShadowWear server ${VERSION} on :${port}`));
}
