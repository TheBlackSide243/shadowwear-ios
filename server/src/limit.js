// How many wrong tries a sign-in gets, in memory (a restart forgets, and is loud enough).
//
// Lockout counts wrong tries per key (an address, the user name). The first `free` are free;
// each one after that locks the key for `baseMs`, doubling up to `maxMs`. A key forgets after
// `forgetMs` with no wrong try, or right away when the caller reports a right one.
//
// A try is counted when it starts, not when its answer is known: a password check takes a tenth
// of a second, and a burst sent all at once would otherwise be checked in full before the first
// failure was written down. A right answer gives the try back.
//
// The Map never grows past `maxKeys`: keys that are not locked and have little to lose go first,
// so flooding fresh addresses cannot push out a lock. `now` can be replaced in the tests.

export function lockout({ free = 5, baseMs = 60_000, maxMs = 3_600_000, forgetMs = 24 * 3_600_000, maxKeys = 5000, now = Date.now } = {}) {
  const keys = new Map();

  function entry(key) {
    const e = keys.get(key);
    if (e && now() - e.last > forgetMs && now() >= e.until) {
      keys.delete(key);
      return null;
    }
    return e ?? null;
  }

  function evict() {
    if (keys.size < maxKeys) return;
    let victim = null;
    let fewest = Infinity;
    for (const [key, e] of keys) {
      if (now() < e.until) continue;
      if (e.count < fewest) {
        fewest = e.count;
        victim = key;
        if (e.count <= 1) break;
      }
    }
    if (victim !== null) keys.delete(victim);
  }

  return {
    /** Milliseconds this key still has to wait (0: it may try). */
    wait(key) {
      const e = entry(key);
      return e ? Math.max(0, e.until - now()) : 0;
    },
    /** Counts a try that may turn out wrong; returns a function that gives it back. */
    attempt(key) {
      let e = entry(key);
      if (!e) {
        evict();
        e = { count: 0, until: 0, last: 0 };
      }
      keys.delete(key);
      keys.set(key, e);
      e.count += 1;
      e.last = now();
      if (e.count > free) e.until = now() + Math.min(maxMs, baseMs * 2 ** (e.count - free - 1));
      let given = false;
      return () => {
        if (given) return;
        given = true;
        e.count = Math.max(0, e.count - 1);
        if (e.count <= free) e.until = 0;
      };
    },
    /** A right answer: everything forgotten for this key. */
    reset(key) {
      keys.delete(key);
    },
    get size() {
      return keys.size;
    },
  };
}

/** A plain budget: at most `max` requests per key in each `windowMs`. */
export function budget({ max = 30, windowMs = 60_000, maxKeys = 5000, now = Date.now } = {}) {
  const keys = new Map();
  return {
    /** True when this request still fits. */
    take(key) {
      const t = now();
      let e = keys.get(key);
      if (!e || t - e.start >= windowMs) {
        if (!e && keys.size >= maxKeys) {
          for (const [k, old] of keys) if (t - old.start >= windowMs) keys.delete(k);
          if (keys.size >= maxKeys) keys.delete(keys.keys().next().value);
        }
        e = { start: t, n: 0 };
        keys.set(key, e);
      }
      e.n += 1;
      return e.n <= max;
    },
  };
}
