// Passwords: how they are hashed, checked and which ones are refused. node:crypto only.
//
// A hash is one string that says how it was made:
//
//     $scrypt$ln=15,r=8,p=1$<salt base64>$<key base64>
//
// so the cost can be raised later: a sign-in with an older or weaker hash stores a new one
// (needsRehash). scrypt with N = 2^15 takes 32 MiB and about a tenth of a second per try: cheap
// for one sign-in, expensive for someone who copied auth.json and wants to guess. Because each
// try costs that much, only two run at once and a short queue waits behind them; past that the
// server answers "busy" instead of running out of memory under a flood of logins.

import crypto from 'node:crypto';

export const MIN_LENGTH = 10;
/** Only to bound the work: a long passphrase is welcome, a megabyte is not. */
export const MAX_LENGTH = 200;

const COST = { ln: 15, r: 8, p: 1 };
const KEY_BYTES = 32;
const SALT_BYTES = 16;
const RUNNING_MAX = 2;
const WAITING_MAX = 24;

export class BusyError extends Error {}

let running = 0;
const queue = [];

function derive(secret, salt, cost, length = KEY_BYTES) {
  const N = 2 ** cost.ln;
  const maxmem = 128 * N * cost.r * cost.p + 8 * 1024 * 1024;
  return new Promise((resolve, reject) => {
    crypto.scrypt(secret, salt, length, { N, r: cost.r, p: cost.p, maxmem }, (error, key) => (error ? reject(error) : resolve(key)));
  });
}

/** derive(), at most RUNNING_MAX at a time. */
async function limited(secret, salt, cost, length) {
  if (running >= RUNNING_MAX) {
    if (queue.length >= WAITING_MAX) throw new BusyError('busy');
    await new Promise((resolve) => queue.push(resolve));
  } else {
    running += 1;
  }
  try {
    return await derive(secret, salt, cost, length);
  } finally {
    const next = queue.shift();
    if (next) next();
    else running -= 1;
  }
}

/** The same password typed on two keyboards is the same password (é as one or two characters). */
const normal = (password) => String(password).normalize('NFKC');

export const length = (password) => [...normal(password)].length;

const write = (cost, salt, key) => `$scrypt$ln=${cost.ln},r=${cost.r},p=${cost.p}$${salt.toString('base64')}$${key.toString('base64')}`;

export async function hashPassword(password) {
  const salt = crypto.randomBytes(SALT_BYTES);
  return write(COST, salt, await limited(normal(password), salt, COST));
}

/** The parts of a stored hash, or null. Costs out of a sane range are refused, so an edited file
 *  cannot make one sign-in take a gigabyte. Hashes of version 0.3 ({salt, hash} in hex, N = 2^14)
 *  are read too: the next right sign-in replaces them. */
function read(stored) {
  if (stored && typeof stored === 'object' && /^[0-9a-f]{32}$/.test(stored.salt) && /^[0-9a-f]{64}$/.test(stored.hash)) {
    // 0.3 used the hex text of the salt as the salt, and did not normalize.
    return { cost: { ln: 14, r: 8, p: 1 }, salt: Buffer.from(stored.salt), key: Buffer.from(stored.hash, 'hex'), legacy: true };
  }
  const m = /^\$scrypt\$ln=(\d+),r=(\d+),p=(\d+)\$([A-Za-z0-9+/]+=*)\$([A-Za-z0-9+/]+=*)$/.exec(typeof stored === 'string' ? stored : '');
  if (!m) return null;
  const cost = { ln: Number(m[1]), r: Number(m[2]), p: Number(m[3]) };
  if (cost.ln < 12 || cost.ln > 18 || cost.r < 1 || cost.r > 16 || cost.p < 1 || cost.p > 4) return null;
  if (128 * 2 ** cost.ln * cost.r > 256 * 1024 * 1024) return null;
  const salt = Buffer.from(m[4], 'base64');
  const key = Buffer.from(m[5], 'base64');
  if (salt.length < 16 || key.length < 16 || key.length > 64) return null;
  return { cost, salt, key, legacy: false };
}

// A hash of a random secret: checking a password against "no account" costs the same time as
// against the real one, so the answer time does not tell anything.
let decoy = null;
function decoyHash() {
  if (!decoy) {
    const salt = crypto.randomBytes(SALT_BYTES);
    decoy = derive(crypto.randomBytes(32).toString('hex'), salt, COST).then((key) => write(COST, salt, key));
    decoy.catch(() => { decoy = null; });
  }
  return decoy;
}

/** Makes the decoy now, so the first wrong sign-in is not slower than the others. */
export const warmUp = () => decoyHash().then(() => {}, () => {});

/** True only when `password` is the one behind `stored`; no hash at all is checked against the decoy. */
export async function verifyPassword(password, stored) {
  if (typeof password !== 'string' || length(password) > MAX_LENGTH) return false;
  const real = read(stored);
  const target = real ?? read(await decoyHash());
  const secret = real?.legacy ? password : normal(password);
  const key = await limited(secret, target.salt, target.cost, target.key.length);
  return Boolean(real) && crypto.timingSafeEqual(key, target.key);
}

export function needsRehash(stored) {
  const h = read(stored);
  return !h || h.legacy || h.cost.ln !== COST.ln || h.cost.r !== COST.r || h.cost.p !== COST.p || h.key.length !== KEY_BYTES;
}

// The passwords every guessing list tries first, the ones long enough to pass MIN_LENGTH. Not a
// leaked-password database (megabytes): wrong tries are locked out long before the long tail.
const COMMON = new Set([
  '1234567890', '0987654321', '12345678910', '123456789012', '1111111111', '0000000000', '9999999999',
  '1q2w3e4r5t', '1q2w3e4r5t6y', 'q1w2e3r4t5', 'qwertyuiop', 'asdfghjkl', '1qaz2wsx3edc', 'qwerty123456',
  'qwertz123456', 'azerty123456', 'password12', 'password123', 'password1234', 'passw0rd123', 'iloveyou123',
  'abcdefghij', 'abcd123456', 'abc1234567', 'a1b2c3d4e5', 'welcome123', 'letmein123', 'changeme123',
  'administrator', '123123123123', '1234512345', '123456123456', 'ciao123456', 'ciaociao12', 'juventus123',
  'napoli1926', 'forzamilan', 'forzajuve1', 'forzanapoli', 'shadowwear', 'shadowwear1', 'shadowwear123',
  'armadio123', 'armadio1234',
]);
// Words people pad with digits and a "!" to reach the length.
const STEMS = new Set([
  'password', 'passw', 'passw0rd', 'parola', 'parolachiave', 'qwerty', 'qwertz', 'azerty', 'qwertyuiop',
  'asdfgh', 'letmein', 'welcome', 'iloveyou', 'tiamo', 'admin', 'administrator', 'amministratore', 'changeme',
  'ciao', 'ciaociao', 'shadowwear', 'shadow', 'wear', 'armadio', 'vestiti', 'closet', 'wardrobe', 'secret',
  'segreto', 'login', 'accesso', 'juventus', 'juve', 'milan', 'inter', 'napoli', 'roma', 'lazio', 'abc', 'abcdef',
]);

/** Why this password cannot be used (an Italian message the clients translate), or null. */
export function passwordProblem(password, user) {
  if (typeof password !== 'string' || length(password) < MIN_LENGTH) return `La password deve avere almeno ${MIN_LENGTH} caratteri.`;
  if (length(password) > MAX_LENGTH) return 'La password è troppo lunga.';
  const low = normal(password).toLowerCase();
  const stem = low.replace(/^[^\p{L}]+|[^\p{L}]+$/gu, '');
  const name = String(user ?? '').normalize('NFKC').trim().toLowerCase();
  if (new Set(low).size <= 3 || COMMON.has(low) || STEMS.has(stem) || (name.length >= 3 && (stem === name || low === name))) {
    return 'Password troppo facile da indovinare: allungala o rendila meno prevedibile.';
  }
  return null;
}
