// The closet on the server: one JSON file (closet.json) and the photos in photos/.
// Same records as the iPhone app (items, outfits, wears), plus tombstones for deletions so a
// piece deleted on one device disappears from the others.

import { promises as fs } from 'node:fs';
import path from 'node:path';

const KINDS = ['items', 'outfits', 'wears'];
const PHOTO_NAME = /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\.(jpg|png)$/;
const ID = /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/;

export function isPhotoName(name) {
  return typeof name === 'string' && PHOTO_NAME.test(name);
}

export function isID(id) {
  return typeof id === 'string' && ID.test(id);
}

/** Dates as the app writes them (ISO 8601); a missing or broken one counts as very old. */
export function time(value) {
  const t = Date.parse(value ?? '');
  return Number.isNaN(t) ? 0 : t;
}

/** Now as the app writes dates: ISO 8601 without milliseconds (its decoder refuses them). */
export function isoNow(ms = Date.now()) {
  return new Date(ms).toISOString().replace(/\.\d{3}Z$/, 'Z');
}

/** The ids are UUIDs: the app writes them upper case, the web lower case. One form only. */
function key(id) {
  return String(id).toUpperCase();
}

export class Store {
  constructor(dir) {
    this.dir = dir;
    this.file = path.join(dir, 'closet.json');
    this.photos = path.join(dir, 'photos');
    this.data = { items: {}, outfits: {}, wears: {}, deleted: {} };
    this.writing = Promise.resolve();
  }

  async open() {
    await fs.mkdir(this.photos, { recursive: true });
    try {
      const raw = JSON.parse(await fs.readFile(this.file, 'utf8'));
      for (const k of [...KINDS, 'deleted']) this.data[k] = raw[k] && typeof raw[k] === 'object' ? raw[k] : {};
    } catch (error) {
      if (error.code !== 'ENOENT') {
        // Never write over a file that did not read: keep it aside and start empty.
        const aside = path.join(this.dir, `closet-illeggibile-${Date.now()}.json`);
        await fs.rename(this.file, aside).catch(() => {});
        console.error(`closet.json unreadable, moved to ${aside}:`, error.message);
      }
    }
    return this;
  }

  /** Writes closet.json (one write at a time, through a temporary file). */
  save() {
    this.writing = this.writing.then(async () => {
      const tmp = `${this.file}.tmp`;
      await fs.writeFile(tmp, JSON.stringify(this.data, null, 1));
      await fs.rename(tmp, this.file);
    });
    return this.writing;
  }

  list(kind) {
    return Object.values(this.data[kind]);
  }

  get(kind, id) {
    return this.data[kind][key(id)];
  }

  /** Puts a record in, unless the one already there was changed later. Returns whether it went in. */
  put(kind, record) {
    if (!KINDS.includes(kind) || !record || !isID(record.id)) return false;
    const id = key(record.id);
    const gone = this.data.deleted[id];
    const stamp = kind === 'wears' ? 0 : time(record.updated);
    if (gone && kind !== 'wears' && stamp <= time(gone.at)) return false;
    if (gone && kind === 'wears') return false;
    const current = this.data[kind][id];
    if (current && kind !== 'wears' && time(current.updated) > stamp) return false;
    this.data[kind][id] = { ...record, id: record.id };
    if (gone) delete this.data.deleted[id];
    return true;
  }

  /** Deletes a record and remembers it, so the other devices delete it too. */
  remove(kind, id, at = isoNow()) {
    if (!KINDS.includes(kind) || !isID(id)) return false;
    const k = key(id);
    const current = this.data[kind][k];
    if (current && kind !== 'wears' && time(current.updated) > time(at)) return false;
    delete this.data[kind][k];
    if (kind === 'items') {
      // Outfits lose the piece, as in the app (the diary keeps it).
      for (const outfit of Object.values(this.data.outfits)) {
        if (Array.isArray(outfit.items) && outfit.items.some((i) => key(i) === k)) {
          outfit.items = outfit.items.filter((i) => key(i) !== k);
          outfit.updated = isoNow(Math.max(Date.now(), time(outfit.updated) + 1000));
        }
      }
    }
    this.data.deleted[k] = { kind, id, at };
    return true;
  }

  /**
   * The first half of a sync. The device says what it has (ids and when each changed) and what it
   * deleted; the answer says what the server needs from it and what it is missing.
   */
  compare(manifest) {
    for (const gone of manifest.deleted ?? []) this.remove(gone.kind, gone.id, gone.at);

    const answer = { need: { items: [], outfits: [], wears: [] }, send: { items: [], outfits: [], wears: [] } };
    for (const kind of KINDS) {
      const theirs = new Map();
      for (const entry of manifest[kind] ?? []) {
        const id = typeof entry === 'string' ? entry : entry?.id;
        if (isID(id)) theirs.set(key(id), typeof entry === 'string' ? 0 : time(entry.updated));
      }
      for (const [id, stamp] of theirs) {
        if (this.data.deleted[id]) continue;
        const mine = this.data[kind][id];
        if (!mine || (kind !== 'wears' && stamp > time(mine.updated))) answer.need[kind].push(id);
      }
      for (const [id, record] of Object.entries(this.data[kind])) {
        if (!theirs.has(id) || (kind !== 'wears' && time(record.updated) > theirs.get(id))) answer.send[kind].push(record);
      }
    }
    answer.deleted = Object.values(this.data.deleted);
    return answer;
  }

  /** The second half: the records the server asked for. */
  push(records) {
    let changed = 0;
    for (const kind of KINDS) {
      for (const record of records[kind] ?? []) if (this.put(kind, record)) changed += 1;
    }
    return changed;
  }

  // Photos

  /** The file of a photo: the id upper case as the app writes it, the extension lower case. */
  photoPath(name) {
    if (!isPhotoName(name)) return null;
    const [base, ext] = name.split('.');
    return path.join(this.photos, `${base.toUpperCase()}.${ext.toLowerCase()}`);
  }

  async photoNames() {
    try {
      return (await fs.readdir(this.photos)).filter(isPhotoName);
    } catch {
      return [];
    }
  }

  async writePhoto(name, bytes) {
    const file = this.photoPath(name);
    if (!file) return false;
    const tmp = `${file}.tmp`;
    await fs.writeFile(tmp, bytes);
    await fs.rename(tmp, file);
    return true;
  }

  /** Photo files no record points to any more (after deletions), removed once older than `age` ms. */
  async prunePhotos(age = 24 * 3_600_000) {
    const used = new Set();
    for (const item of this.list('items')) {
      for (const photo of item.photos ?? []) {
        used.add(`${key(photo.id)}.jpg`);
        used.add(`${key(photo.id)}.png`);
      }
    }
    let removed = 0;
    for (const name of await this.photoNames()) {
      if (used.has(name.toUpperCase().replace(/\.(JPG|PNG)$/, (m) => m.toLowerCase()))) continue;
      const file = path.join(this.photos, name);
      const stat = await fs.stat(file).catch(() => null);
      if (!stat || Date.now() - stat.mtimeMs < age) continue;
      await fs.rm(file, { force: true });
      removed += 1;
    }
    return removed;
  }
}
