// The one account of the closet and the ways into it, stored in auth.json next to the closet.
//
// Nothing in that file can sign anybody in if it is copied:
// - the password is kept only as a slow scrypt hash (password.js);
// - a device or browser holds a random 256-bit token, and the file only its SHA-256;
// - a passkey is a public key (webauthn.js): the private one never leaves the phone or computer;
// - a code to connect a new device is kept only as a SHA-256, lives ten minutes and works once.
// A token nobody used for TOKEN_DAYS days stops working; every use moves the date forward.

import { promises as fs } from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { hashPassword, verifyPassword, needsRehash, passwordProblem } from './password.js';

export const TOKEN_DAYS = 90;
const DAY = 86_400_000;
export const LINK_MINUTES = 10;
// No 0/O and 1/I: a code is read off a screen.
const LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

const sha = (text) => crypto.createHash('sha256').update(text).digest('hex');

function same(a, b) {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

/** How a user name is compared: "Anna", "anna " and "ＡＮＮＡ" are the same. */
export const nameKey = (name) => String(name ?? '').normalize('NFKC').trim().toLowerCase();

/** 12 random letters and digits (60 bits) as XXXX-XXXX-XXXX. */
export function makeCode() {
  // 256 is a multiple of 32: every character is equally likely.
  const raw = Array.from(crypto.randomBytes(12), (b) => LETTERS[b % LETTERS.length]).join('');
  return `${raw.slice(0, 4)}-${raw.slice(4, 8)}-${raw.slice(8)}`;
}
const cleanCode = (code) => String(code ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '');
const hashCode = (code) => sha(`shadowwear-link:${cleanCode(code)}`);

export class Auth {
  constructor(dir, { now = Date.now } = {}) {
    this.file = path.join(dir, 'auth.json');
    this.now = now;
    this.data = Auth.empty();
  }

  static empty() {
    return { user: null, password: null, userHandle: null, tokens: [], passkeys: [], link: null };
  }

  async open() {
    try {
      this.data = { ...Auth.empty(), ...JSON.parse(await fs.readFile(this.file, 'utf8')) };
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    this.data.tokens ??= [];
    this.data.passkeys ??= [];
    // The random id passkeys carry for the account (servers of 0.3 had none): written with the next save.
    this.data.userHandle ??= crypto.randomBytes(16).toString('base64url');
    return this;
  }

  async save() {
    const tmp = `${this.file}.tmp`;
    await fs.writeFile(tmp, JSON.stringify(this.data, null, 1), { mode: 0o600 });
    await fs.rename(tmp, this.file);
    await fs.chmod(this.file, 0o600).catch(() => {});
  }

  get configured() {
    return Boolean(this.data.password);
  }

  get user() {
    return this.data.user;
  }

  /** Sets the user name, the password or both (null keeps the current one). */
  async setAccount(user, password) {
    const name = user === null ? this.data.user : typeof user === 'string' ? user.normalize('NFKC').trim() : '';
    if (user !== null && (!name || [...name].length > 40 || /[\s:]/.test(name))) throw new Error('Il nome utente deve avere da 1 a 40 caratteri, senza spazi.');
    if (password !== null) {
      const problem = passwordProblem(password, name);
      if (problem) throw new Error(problem);
    }
    if (user !== null) this.data.user = name;
    if (password !== null) {
      this.data.password = await hashPassword(password);
      // A new password closes every way in it opened: all devices and the code in waiting.
      // Passkeys stay: they never depended on the password.
      this.data.tokens = [];
      this.data.link = null;
    }
    await this.save();
  }

  /** Right user name (any case) and password. The password is hashed even when the name is wrong. */
  async check(user, password) {
    const right = await verifyPassword(password, this.data.password);
    // Servers set up before user names: only the password counts until a name is chosen.
    const nameRight = !this.data.user || nameKey(user) === nameKey(this.data.user);
    if (right && nameRight && needsRehash(this.data.password)) {
      // A hash made with an older, cheaper recipe: replaced now that the password is known.
      this.data.password = await hashPassword(password);
      await this.save();
    }
    return right && nameRight;
  }

  // ---------- tokens: one per device or browser ----------

  async issue(name, via) {
    const token = crypto.randomBytes(32).toString('base64url');
    const at = new Date(this.now()).toISOString();
    this.data.tokens.push({
      id: crypto.randomUUID(),
      name: String(name || 'Dispositivo').slice(0, 80),
      hash: sha(token),
      created: at,
      seen: at,
      via: via ?? 'password',
    });
    await this.save();
    return token;
  }

  /** The device behind a token, or null (also when it went unused for TOKEN_DAYS days). */
  find(token) {
    if (typeof token !== 'string' || token.length < 20 || token.length > 100) return null;
    const digest = sha(token);
    const device = this.data.tokens.find((t) => same(t.hash, digest));
    if (!device) return null;
    const now = this.now();
    if (now - Date.parse(device.seen) > TOKEN_DAYS * DAY) {
      this.data.tokens = this.data.tokens.filter((t) => t !== device);
      this.save().catch(() => {});
      return null;
    }
    // Last used, at most once an hour (no write on every request).
    if (now - Date.parse(device.seen) > 3_600_000) {
      device.seen = new Date(now).toISOString();
      this.save().catch(() => {});
    }
    return device;
  }

  devices() {
    const now = this.now();
    return this.data.tokens
      .filter((t) => now - Date.parse(t.seen) <= TOKEN_DAYS * DAY)
      .map(({ id, name, created, seen, via }) => ({ id, name, created, seen, via: via ?? 'password' }));
  }

  async revoke(id) {
    const before = this.data.tokens.length;
    this.data.tokens = this.data.tokens.filter((t) => t.id !== id);
    if (this.data.tokens.length !== before) await this.save();
    return this.data.tokens.length !== before;
  }

  /** Every device but one out (after a password change, for example). */
  async revokeOthers(keepId) {
    this.data.tokens = this.data.tokens.filter((t) => t.id === keepId);
    this.data.link = null;
    await this.save();
  }

  // ---------- passkeys ----------

  get userHandle() {
    return this.data.userHandle;
  }

  passkeys() {
    return this.data.passkeys.map(({ id, name, created, used, rpId }) => ({ id, name, created, used, site: rpId }));
  }

  passkey(id) {
    return this.data.passkeys.find((p) => typeof id === 'string' && same(p.id, id)) ?? null;
  }

  async addPasskey(key, name) {
    if (this.passkey(key.id)) throw new Error("Questa passkey c'è già.");
    if (this.data.passkeys.length >= 20) throw new Error('Ci sono già 20 passkey: eliminane una.');
    const at = new Date(this.now()).toISOString();
    this.data.passkeys.push({ ...key, name: String(name || 'Passkey').slice(0, 80), created: at, used: null });
    await this.save();
  }

  async usedPasskey(passkey, signCount) {
    passkey.signCount = signCount;
    passkey.used = new Date(this.now()).toISOString();
    await this.save();
  }

  async removePasskey(id) {
    const before = this.data.passkeys.length;
    this.data.passkeys = this.data.passkeys.filter((p) => p.id !== id);
    if (this.data.passkeys.length !== before) await this.save();
    return this.data.passkeys.length !== before;
  }

  // ---------- a code to connect a new device ----------

  /** A new code (the one before stops working). Returned once, never stored. */
  async makeLink() {
    const code = makeCode();
    const expires = this.now() + LINK_MINUTES * 60_000;
    this.data.link = { hash: hashCode(code), expires };
    await this.save();
    return { code, expires: new Date(expires).toISOString() };
  }

  /** True once for the live code; a wrong, used or expired code all look the same. */
  async useLink(code) {
    const link = this.data.link;
    if (!link || cleanCode(code).length !== 12) return false;
    if (link.expires <= this.now()) {
      this.data.link = null;
      await this.save();
      return false;
    }
    if (!same(hashCode(code), link.hash)) return false;
    this.data.link = null;
    await this.save();
    return true;
  }

  get linkExpires() {
    const link = this.data.link;
    return link && link.expires > this.now() ? new Date(link.expires).toISOString() : null;
  }
}
