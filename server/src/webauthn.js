// Passkeys (WebAuthn) without libraries: a small CBOR reader, the COSE public keys the
// authenticators send, and the two checks — a new passkey, and a sign-in with one.
//
// What the server keeps of a passkey is its public key: nothing in auth.json can sign anybody
// in. Each ceremony has its own random challenge, used once and good for five minutes; the
// answer must come from a page of this server (origin), for this site (rpIdHash), with the
// person present and verified (Face ID, fingerprint, PIN: flags UP and UV).
// Attestation is not asked for ("none"): who made the authenticator does not matter here.

import crypto from 'node:crypto';

export class PasskeyError extends Error {}

const fail = (message) => {
  throw new PasskeyError(message);
};

export const b64url = (bytes) => Buffer.from(bytes).toString('base64url');
export const fromB64url = (text) => {
  if (typeof text !== 'string' || !/^[A-Za-z0-9_-]*$/.test(text)) fail('Dati della passkey non validi.');
  return Buffer.from(text, 'base64url');
};

// ---------- CBOR (RFC 8949), the part WebAuthn uses ----------

/** The first CBOR value in `buf` from `at`: { value, end }. Maps come back as Map (keys can be numbers). */
export function cbor(buf, at = 0, depth = 0) {
  if (depth > 16) fail('CBOR troppo annidato.');
  const need = (n) => {
    if (at + n > buf.length) fail('CBOR troncato.');
  };
  need(1);
  const first = buf[at++];
  const major = first >> 5;
  const info = first & 31;
  let arg;
  if (info < 24) arg = info;
  else if (info === 24) { need(1); arg = buf[at]; at += 1; }
  else if (info === 25) { need(2); arg = buf.readUInt16BE(at); at += 2; }
  else if (info === 26) { need(4); arg = buf.readUInt32BE(at); at += 4; }
  else if (info === 27) {
    need(8);
    const big = buf.readBigUInt64BE(at);
    if (big > BigInt(Number.MAX_SAFE_INTEGER)) fail('Numero CBOR troppo grande.');
    arg = Number(big);
    at += 8;
  } else fail('CBOR a lunghezza indefinita non supportato.');

  switch (major) {
    case 0: return { value: arg, end: at };
    case 1: return { value: -1 - arg, end: at };
    case 2: need(arg); return { value: buf.subarray(at, at + arg), end: at + arg };
    case 3: need(arg); return { value: buf.subarray(at, at + arg).toString('utf8'), end: at + arg };
    case 4: {
      if (arg > 1000) fail('CBOR troppo lungo.');
      const list = [];
      for (let i = 0; i < arg; i++) {
        const item = cbor(buf, at, depth + 1);
        list.push(item.value);
        at = item.end;
      }
      return { value: list, end: at };
    }
    case 5: {
      if (arg > 1000) fail('CBOR troppo lungo.');
      const map = new Map();
      for (let i = 0; i < arg; i++) {
        const key = cbor(buf, at, depth + 1);
        const value = cbor(buf, key.end, depth + 1);
        map.set(key.value, value.value);
        at = value.end;
      }
      return { value: map, end: at };
    }
    case 6: return cbor(buf, at, depth + 1); // a tag: the value inside
    default:
      if (info === 20) return { value: false, end: at };
      if (info === 21) return { value: true, end: at };
      if (info === 22 || info === 23) return { value: null, end: at };
      fail('Valore CBOR non supportato.');
  }
  return null;
}

// ---------- COSE keys ----------

const ES256 = -7;
const EDDSA = -8;
const RS256 = -257;
export const ALGORITHMS = [ES256, EDDSA, RS256];

/** A COSE public key (as a Map) → { pem, alg }. */
export function coseToKey(cose) {
  if (!(cose instanceof Map)) fail('Chiave della passkey non valida.');
  const kty = cose.get(1);
  const alg = cose.get(3);
  let jwk;
  if (kty === 2 && alg === ES256 && cose.get(-1) === 1) {
    const x = cose.get(-2);
    const y = cose.get(-3);
    if (!Buffer.isBuffer(x) || !Buffer.isBuffer(y) || x.length !== 32 || y.length !== 32) fail('Chiave della passkey non valida.');
    jwk = { kty: 'EC', crv: 'P-256', x: b64url(x), y: b64url(y) };
  } else if (kty === 1 && alg === EDDSA && cose.get(-1) === 6) {
    const x = cose.get(-2);
    if (!Buffer.isBuffer(x) || x.length !== 32) fail('Chiave della passkey non valida.');
    jwk = { kty: 'OKP', crv: 'Ed25519', x: b64url(x) };
  } else if (kty === 3 && alg === RS256) {
    const n = cose.get(-1);
    const e = cose.get(-2);
    if (!Buffer.isBuffer(n) || !Buffer.isBuffer(e) || n.length < 256) fail('Chiave della passkey non valida.');
    jwk = { kty: 'RSA', n: b64url(n), e: b64url(e) };
  } else {
    fail('Tipo di passkey non supportato.');
  }
  const key = crypto.createPublicKey({ key: jwk, format: 'jwk' });
  return { pem: key.export({ type: 'spki', format: 'pem' }), alg };
}

// ---------- authenticator data ----------

const UP = 0x01;
const UV = 0x04;
const AT = 0x40;

export function authData(buf) {
  if (buf.length < 37) fail('Dati della passkey troppo corti.');
  const out = { rpIdHash: buf.subarray(0, 32), flags: buf[32], signCount: buf.readUInt32BE(33) };
  if (out.flags & AT) {
    if (buf.length < 55) fail('Dati della passkey troppo corti.');
    const idLength = buf.readUInt16BE(53);
    if (idLength < 16 || idLength > 1023 || buf.length < 55 + idLength) fail('Id della passkey non valido.');
    out.credentialId = buf.subarray(55, 55 + idLength);
    out.publicKey = cbor(buf, 55 + idLength).value;
  }
  return out;
}

const sha256 = (data) => crypto.createHash('sha256').update(data).digest();

function sameBytes(a, b) {
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

/** The page the answer came from: an https address of this server (http only on this computer). */
export function originOK(origin, host) {
  let url;
  try {
    url = new URL(origin);
  } catch {
    return null;
  }
  if (url.origin !== origin || url.host !== String(host || '').toLowerCase()) return null;
  const local = url.hostname === 'localhost' || url.hostname === '127.0.0.1' || url.hostname === '[::1]';
  if (url.protocol !== 'https:' && !(url.protocol === 'http:' && local)) return null;
  return url.hostname;
}

function clientData(text, type, challenge, host) {
  let data;
  try {
    data = JSON.parse(fromB64url(text).toString('utf8'));
  } catch {
    fail('Dati della passkey non validi.');
  }
  if (data?.type !== type) fail('Dati della passkey non validi.');
  if (typeof data.challenge !== 'string' || !sameBytes(Buffer.from(data.challenge), Buffer.from(challenge))) fail('Richiesta della passkey scaduta: riprova.');
  const rpId = originOK(data.origin, host);
  if (!rpId) fail('La passkey funziona solo dal sito del server in https.');
  return rpId;
}

function present(flags) {
  if (!(flags & UP) || !(flags & UV)) fail('La passkey non ha verificato chi sei (Face ID, impronta o PIN).');
}

/** A new passkey: `response` is what navigator.credentials.create() gave, in base64url. */
export function verifyRegistration(response, { challenge, host }) {
  const rpId = clientData(response?.clientDataJSON, 'webauthn.create', challenge, host);
  const att = cbor(fromB64url(response?.attestationObject)).value;
  if (!(att instanceof Map) || !Buffer.isBuffer(att.get('authData'))) fail('Dati della passkey non validi.');
  const data = authData(att.get('authData'));
  if (!sameBytes(data.rpIdHash, sha256(rpId))) fail('La passkey è di un altro sito.');
  present(data.flags);
  if (!data.credentialId) fail('Dati della passkey non validi.');
  const key = coseToKey(data.publicKey);
  return { id: b64url(data.credentialId), rpId, publicKey: key.pem, alg: key.alg, signCount: data.signCount };
}

/** A sign-in with a stored passkey; returns the new signature counter. */
export function verifyAssertion(response, passkey, { challenge, host }) {
  const rpId = clientData(response?.clientDataJSON, 'webauthn.get', challenge, host);
  if (rpId !== passkey.rpId) fail('La passkey è di un altro sito.');
  const raw = fromB64url(response?.authenticatorData);
  const data = authData(raw);
  if (!sameBytes(data.rpIdHash, sha256(rpId))) fail('La passkey è di un altro sito.');
  present(data.flags);
  const signed = Buffer.concat([raw, sha256(fromB64url(response.clientDataJSON))]);
  const signature = fromB64url(response?.signature);
  let ok = false;
  try {
    ok = crypto.verify(passkey.alg === EDDSA ? null : 'sha256', signed, crypto.createPublicKey(passkey.publicKey), signature);
  } catch {
    // A signature that is not even well formed.
  }
  if (!ok) fail('Firma della passkey non valida.');
  // Passkeys that sync between devices always say 0; a counter that goes back means a copy.
  if (data.signCount !== 0 || passkey.signCount !== 0) {
    if (data.signCount <= passkey.signCount) fail('Questa passkey sembra copiata: eliminala e creane una nuova.');
  }
  return data.signCount;
}

/** Random challenges, each used once. */
export function challenges({ ttlMs = 5 * 60_000, max = 200, now = Date.now } = {}) {
  const live = new Map();
  const prune = () => {
    for (const [k, v] of live) if (v.exp <= now()) live.delete(k);
    while (live.size >= max) live.delete(live.keys().next().value);
  };
  return {
    make(purpose, extra = {}) {
      prune();
      const challenge = b64url(crypto.randomBytes(32));
      live.set(challenge, { purpose, exp: now() + ttlMs, ...extra });
      return challenge;
    },
    /** Takes the challenge inside clientDataJSON, if it is live and for this purpose. */
    take(clientDataJSON, purpose) {
      let challenge;
      try {
        challenge = JSON.parse(fromB64url(clientDataJSON).toString('utf8')).challenge;
      } catch {
        return null;
      }
      const entry = typeof challenge === 'string' ? live.get(challenge) : null;
      if (!entry) return null;
      live.delete(challenge);
      if (entry.exp <= now() || entry.purpose !== purpose) return null;
      return { challenge, ...entry };
    },
  };
}
