// One password for the closet (set on the first visit), and tokens: one per device or browser.
// Stored in auth.json next to the closet; only hashes are kept.

import { promises as fs } from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

function hash(secret, salt) {
  return new Promise((resolve, reject) => {
    crypto.scrypt(secret, salt, 32, { N: 16384, r: 8, p: 1 }, (error, key) => (error ? reject(error) : resolve(key.toString('hex'))));
  });
}

function sha(text) {
  return crypto.createHash('sha256').update(text).digest('hex');
}

function same(a, b) {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

export class Auth {
  constructor(dir) {
    this.file = path.join(dir, 'auth.json');
    this.data = { password: null, tokens: [] };
    // Wrong passwords per address, to slow down guessing.
    this.failures = new Map();
  }

  async open() {
    try {
      this.data = { password: null, tokens: [], ...JSON.parse(await fs.readFile(this.file, 'utf8')) };
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    return this;
  }

  async save() {
    const tmp = `${this.file}.tmp`;
    await fs.writeFile(tmp, JSON.stringify(this.data, null, 1), { mode: 0o600 });
    await fs.rename(tmp, this.file);
  }

  get configured() {
    return Boolean(this.data.password);
  }

  async setPassword(password) {
    if (typeof password !== 'string' || password.length < 8) throw new Error('La password deve avere almeno 8 caratteri.');
    const salt = crypto.randomBytes(16).toString('hex');
    this.data.password = { salt, hash: await hash(password, salt) };
    // A new password signs every device out.
    this.data.tokens = [];
    await this.save();
  }

  async check(password) {
    if (!this.configured || typeof password !== 'string') return false;
    return same(await hash(password, this.data.password.salt), this.data.password.hash);
  }

  /** Waits that grow with the wrong passwords from the same address (none after a right one). */
  delay(address) {
    const n = this.failures.get(address) ?? 0;
    return Math.min(n * 500, 8000);
  }

  failed(address) {
    this.failures.set(address, (this.failures.get(address) ?? 0) + 1);
  }

  succeeded(address) {
    this.failures.delete(address);
  }

  async issue(name) {
    const token = crypto.randomBytes(32).toString('base64url');
    this.data.tokens.push({
      id: crypto.randomUUID(),
      name: String(name || 'Dispositivo').slice(0, 80),
      hash: sha(token),
      created: new Date().toISOString(),
      seen: new Date().toISOString(),
    });
    await this.save();
    return token;
  }

  /** The device behind a token, or null. */
  find(token) {
    if (typeof token !== 'string' || !token) return null;
    const digest = sha(token);
    const device = this.data.tokens.find((t) => same(t.hash, digest));
    if (device) {
      const now = Date.now();
      // Remember when it was last used, at most once an hour (no write on every request).
      if (now - Date.parse(device.seen) > 3_600_000) {
        device.seen = new Date(now).toISOString();
        this.save().catch(() => {});
      }
    }
    return device ?? null;
  }

  devices() {
    return this.data.tokens.map(({ id, name, created, seen }) => ({ id, name, created, seen }));
  }

  async revoke(id) {
    const before = this.data.tokens.length;
    this.data.tokens = this.data.tokens.filter((t) => t.id !== id);
    if (this.data.tokens.length !== before) await this.save();
    return this.data.tokens.length !== before;
  }
}
