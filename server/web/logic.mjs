// What the site works out from the closet, the same way the iPhone app does: the ideas of the day,
// the suitcase, what to wash, the change of season, the clear-out and the numbers.
// Only functions of their arguments (no page, no network), so they are tested with node.

export const up = (id) => String(id).toUpperCase();

// ---------- days ----------

export function dayKey(date) {
  const p = (n) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${p(date.getMonth() + 1)}-${p(date.getDate())}`;
}

export function fromKey(key) {
  const [y, m, d] = String(key).split('-').map(Number);
  return new Date(y, m - 1, d);
}

export function addDays(date, n) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + n);
}

/** Whole days from the day `key` to `today` (0 for today, 1 for yesterday). */
export function dayDistance(key, today) {
  const from = fromKey(key);
  if (Number.isNaN(from.getTime())) return null;
  const to = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  return Math.round((to - from) / 86_400_000);
}

// ---------- pieces ----------

export const CATEGORY_ORDER = ['top', 'bottom', 'dress', 'outerwear', 'shoes', 'bag', 'accessory', 'ski', 'other'];

/** Kept apart from the everyday closet: the ski gear has its own section, and the ideas of the day,
 * the laundry, the change of season and the clear-out leave it alone. */
export const apart = (item) => item.category === 'ski';

/** The filter of the grids: a kind shows its pieces; no kind shows the everyday closet. */
export const showsKind = (kind, item) => (kind ? item.category === kind : !apart(item));
export const SEASONS = ['spring', 'summer', 'autumn', 'winter'];

/** How warm a piece is (0 light, 1 medium, 2 warm): what was chosen, or coats warm and the rest in between. */
export function warmthOf(item) {
  return typeof item.warmth === 'number' ? item.warmth : (item.category === 'outerwear' ? 2 : 1);
}

/** The seasons a piece is for: the ones chosen, or from how warm it is. */
export function seasonsOf(item) {
  const chosen = (item.seasons ?? []).filter((s) => SEASONS.includes(s));
  if (chosen.length) return new Set(chosen);
  const warmth = warmthOf(item);
  if (warmth === 0) return new Set(['spring', 'summer']);
  if (warmth === 2) return new Set(['autumn', 'winter']);
  return new Set(SEASONS);
}

export function seasonOf(date, south = false) {
  const month = date.getMonth() + 1;
  const north = month >= 3 && month <= 5 ? 'spring' : month >= 6 && month <= 8 ? 'summer' : month >= 9 && month <= 11 ? 'autumn' : 'winter';
  return south ? { spring: 'autumn', summer: 'winter', autumn: 'spring', winter: 'summer' }[north] : north;
}

// ---------- weather ----------

/** What a day feels like in the hours spent out: mostly the highest temperature. */
export function band(conditions) {
  const day = conditions.high * 0.7 + conditions.low * 0.3;
  if (day < 9) return 'cold';
  if (day < 17) return 'cool';
  if (day < 25) return 'mild';
  return 'hot';
}

export const rainy = (conditions) => (conditions.rain ?? 0) >= 50;

/** The forecast of a day as conditions, when its temperatures are known. */
export function conditionsOf(day) {
  return typeof day?.high === 'number' && typeof day?.low === 'number' ? { high: day.high, low: day.low, rain: day.rain ?? 0 } : null;
}

// ---------- the diary ----------

/** The days each piece was worn: id → Set of days. */
export function wornDays(wears) {
  const out = new Map();
  for (const wear of wears) for (const id of wear.items ?? []) {
    const k = up(id);
    if (!out.has(k)) out.set(k, new Set());
    out.get(k).add(wear.day);
  }
  return out;
}

/** The last day each piece was worn: id → day. */
export function lastWorn(wears) {
  const out = new Map();
  for (const wear of wears) for (const id of wear.items ?? []) {
    const k = up(id);
    if ((out.get(k) ?? '') < wear.day) out.set(k, wear.day);
  }
  return out;
}

/** Liked minus not liked, for each piece. */
export function affinity(wears) {
  const out = new Map();
  for (const wear of wears) {
    if (!wear.rating) continue;
    for (const id of wear.items ?? []) out.set(up(id), (out.get(up(id)) ?? 0) + (wear.rating > 0 ? 1 : -1));
  }
  return out;
}

// ---------- washing ----------

const WASH_EVERY = { top: 2, dress: 2, bottom: 4, outerwear: 12 };

/** Wears between two washes: the piece's own, or the usual for its kind; null for what is not washed. */
export function washEvery(item) {
  if (typeof item.washEvery === 'number') return item.washEvery > 0 ? item.washEvery : null;
  return WASH_EVERY[item.category] ?? null;
}

/** Days a piece was worn after its last wash (each day once). */
export function wearsSinceWash(item, wears) {
  const since = item.washed ? dayKey(new Date(item.washed)) : '';
  const k = up(item.id);
  return new Set(wears.filter((w) => w.day > since && (w.items ?? []).some((i) => up(i) === k)).map((w) => w.day)).size;
}

/** The pieces to wash, the most worn first. */
export function laundry(items, wears) {
  return items
    .map((item) => ({ item, times: wearsSinceWash(item, wears), every: washEvery(item) }))
    .filter((e) => e.every !== null && e.times >= e.every)
    .sort((a, b) => b.times - a.times);
}

// ---------- seasons ----------

/** What to put away and what to bring out for the season of `date` and the one a month later. */
export function seasonSwap(items, date = new Date(), south = false) {
  const now = seasonOf(date, south);
  const wanted = new Set([now, seasonOf(addDays(date, 30), south)]);
  const inSeason = (item) => [...seasonsOf(item)].some((s) => wanted.has(s));
  return {
    season: now,
    // The ski gear is kept apart: it is not the season that puts it away.
    putAway: items.filter((i) => !apart(i) && !i.stored && !inSeason(i)),
    bringOut: items.filter((i) => !apart(i) && i.stored && inSeason(i)),
  };
}

// ---------- clear-out ----------

/** The pieces not worn for `months` (or never, after `months` in the closet), the oldest first.
 * Pieces put away, pieces kept recently and the ski gear (worn a week a year) are left out. */
export function clearOut(items, wears, months, today = new Date()) {
  const limit = new Date(today.getFullYear(), today.getMonth() - months, today.getDate());
  const limitKey = dayKey(limit);
  const last = lastWorn(wears);
  const days = wornDays(wears);
  return items.flatMap((item) => {
    if (item.stored || apart(item)) return [];
    if (item.keepUntil && new Date(item.keepUntil) > today) return [];
    const day = last.get(up(item.id));
    if (day) {
      if (!(day < limitKey)) return [];
    } else if (!(new Date(item.created ?? 0) < limit)) return [];
    return [{ item, lastWorn: day ?? null, times: days.get(up(item.id))?.size ?? 0 }];
  }).sort((a, b) => (a.lastWorn ?? '').localeCompare(b.lastWorn ?? ''));
}

// ---------- the idea of the day ----------

/** A small random generator that gives the same numbers for the same seed, so the idea of the day
 * stays put until another one is asked for. */
export function seeded(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4_294_967_296;
  };
}

/** The seed for a day: the same all day long, different the next. */
export function seedFor(text, shuffle = 0) {
  let hash = 2_166_136_261;
  for (let i = 0; i < text.length; i += 1) hash = Math.imul(hash ^ text.charCodeAt(i), 16_777_619);
  return (hash + Math.imul(shuffle, 0x9e3779b9)) >>> 0;
}

const NEUTRALS = new Set(['black', 'white', 'grey', 'beige', 'brown', 'navy']);

/** Something for the body and the legs: a dress, or a top with a bottom. */
export function wearable(pieces) {
  const kinds = new Set(pieces.map((p) => p.category));
  return kinds.has('dress') || (kinds.has('top') && kinds.has('bottom'));
}

/** How much the main colors fight: two strong colors that are not the same (denim goes with anything). */
export function clash(pieces) {
  const strong = new Set(pieces
    .filter((p) => ['top', 'bottom', 'dress', 'outerwear'].includes(p.category))
    .map((p) => p.colors?.[0])
    .filter((c) => c && !NEUTRALS.has(c) && c !== 'blue' && c !== 'lightblue'));
  return strong.size > 1 ? (strong.size - 1) * 1.2 : 0;
}

function pieceScore(item, ctx) {
  let s = 0;
  const k = up(item.id);
  // Waiting for a wash: only if nothing else will do.
  if (ctx.dirty.has(k)) s -= 2.5;
  // Liked days lift a piece, days not liked lower it (a little each, up to a point).
  s += Math.max(-3, Math.min(3, ctx.affinity.get(k) ?? 0)) * 0.25;
  if (ctx.band) {
    const warmth = warmthOf(item);
    if ((ctx.band === 'cold' && warmth === 2) || (ctx.band === 'hot' && warmth === 0)) s += 1;
    else if ((ctx.band === 'cold' && warmth === 0) || (ctx.band === 'hot' && warmth === 2)) s -= 1.5;
    else if (ctx.band === 'cool' && warmth === 0) s -= 0.5;
    else if (ctx.band === 'mild' && warmth === 2) s -= 0.7;
  }
  const day = ctx.lastWorn.get(k);
  const gap = day ? dayDistance(day, ctx.today) : null;
  if (gap === null) s += 0.4; // never worn: give it a go
  else if (gap < 2) s -= 2;
  else if (gap < 4) s -= 1;
  else if (gap < 8) s -= 0.4;
  else s += 0.2;
  if (item.favorite) s += 0.3;
  return s;
}

/** How good the pieces are for today: higher is better, around 0 is fine. */
export function outfitScore(pieces, ctx) {
  if (!pieces.length) return -10;
  let total = pieces.reduce((sum, p) => sum + pieceScore(p, ctx), 0) / pieces.length;
  const coat = pieces.some((p) => p.category === 'outerwear');
  if (ctx.band === 'cold') total += coat ? 1.5 : -3;
  else if (ctx.band === 'cool') total += coat ? 1 : -1;
  else if (ctx.band === 'mild') total += coat ? -0.5 : 0.3;
  else if (ctx.band === 'hot') total += coat ? -2.5 : 0.5;
  return total - clash(pieces);
}

function combine(items, ctx, random) {
  const pick = (category, chosen) => {
    const options = items.filter((i) => i.category === category);
    if (!options.length) return null;
    // Better pieces are likelier, but every one has a chance.
    const weights = options.map((o) => Math.exp(pieceScore(o, ctx) - clash([...chosen, o])));
    let r = random() * weights.reduce((a, b) => a + b, 0);
    for (let i = 0; i < options.length; i += 1) {
      r -= weights[i];
      if (r <= 0) return options[i];
    }
    return options[options.length - 1];
  };
  const count = (category) => items.filter((i) => i.category === category).length;
  const dresses = count('dress');
  const tops = count('top');
  const canSplit = tops > 0 && count('bottom') > 0;
  if (!dresses && !canSplit) return null;

  const chosen = [];
  const add = (category) => {
    const piece = pick(category, chosen);
    if (piece) chosen.push(piece);
  };
  if (dresses > 0 && random() < (canSplit ? dresses / (dresses + tops) : 1)) add('dress');
  else {
    add('top');
    add('bottom');
  }
  if (ctx.band === 'cold' || ctx.band === 'cool') add('outerwear');
  else if (ctx.band === 'mild') { if (random() < 0.25) add('outerwear'); }
  else if (!ctx.band && random() < 0.4) add('outerwear');
  add('shoes');
  if (random() < 0.4) add('bag');
  if (random() < 0.4) add('accessory');
  return chosen;
}

/**
 * The ideas for the day, best first: saved outfits and new combinations together. Pieces put away
 * for the season stay out; pieces to wash and the liked ones weigh in.
 */
export function suggestions({ items, outfits, wears, conditions = null, today = new Date(), seed = 1, count = 8 }) {
  // Not what is put away, and not the ski gear: it is not for every day.
  const usable = items.filter((i) => !i.stored && !apart(i));
  const byID = new Map(usable.map((i) => [up(i.id), i]));
  const ctx = {
    today,
    band: conditions ? band(conditions) : null,
    lastWorn: lastWorn(wears),
    affinity: affinity(wears),
    dirty: new Set(laundry(usable, wears).map((e) => up(e.item.id))),
  };
  const outfitLast = new Map();
  for (const wear of wears) if (wear.outfit && (outfitLast.get(up(wear.outfit)) ?? '') < wear.day) outfitLast.set(up(wear.outfit), wear.day);

  const ideas = [];
  for (const outfit of outfits) {
    const pieces = (outfit.items ?? []).map((id) => byID.get(up(id))).filter(Boolean);
    if (!pieces.length || !wearable(pieces)) continue;
    let score = outfitScore(pieces, ctx);
    if (outfit.favorite) score += 0.5;
    const day = outfitLast.get(up(outfit.id));
    const gap = day ? dayDistance(day, today) : null;
    if (gap !== null && gap < 7) score -= gap < 2 ? 3 : 1.5;
    ideas.push({ items: pieces.map((p) => p.id), outfit: outfit.id, score });
  }
  const random = seeded(seed);
  for (let i = 0; i < 24; i += 1) {
    const pieces = combine(usable, ctx, random);
    if (!pieces) break;
    ideas.push({ items: pieces.map((p) => p.id), outfit: null, score: outfitScore(pieces, ctx) });
  }
  // The same pieces only once: a saved outfit wins over the same combination made up.
  const seen = new Set();
  const unique = [];
  for (const idea of [...ideas].sort((a, b) => (Boolean(b.outfit) - Boolean(a.outfit)) || b.score - a.score)) {
    const key = idea.items.map(up).sort().join(',');
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(idea);
  }
  return unique.sort((a, b) => b.score - a.score).slice(0, count);
}

// ---------- the suitcase ----------

/** How many pieces of each kind a trip calls for: its length, the weather and what it is for. */
export function packingCounts({ days, conditions, occasions, items }) {
  const has = new Set(items.map((i) => i.category));
  const bands = new Set(conditions.map(band));
  const wet = conditions.some(rainy);
  const out = {};
  // Up to a week without washing; longer trips wash once.
  const wearDays = Math.min(days, 7);
  out.top = wearDays;
  out.bottom = Math.max(1, Math.ceil(wearDays / 3));
  if (has.has('dress') && (occasions.has('evening') || !has.has('top'))) {
    out.dress = occasions.has('evening') ? Math.min(2, Math.max(1, Math.floor(days / 3))) : Math.max(1, Math.floor(wearDays / 2));
  }
  out.outerwear = bands.has('cold') || bands.has('cool') || wet || !conditions.length ? 1 : 0;
  out.shoes = Math.min(3, 1 + (occasions.has('sport') ? 1 : 0) + (occasions.has('evening') || occasions.has('work') ? 1 : 0));
  out.bag = 1;
  out.accessory = bands.has('cold') ? 2 : 1;
  if (occasions.has('sport')) out.top += Math.min(2, Math.floor(days / 2) + 1);
  return Object.fromEntries(Object.entries(out).filter(([, n]) => n > 0));
}

function packingFit(item, conditions, occasions, liking) {
  let s = 0;
  if (conditions.length) {
    const warmth = warmthOf(item);
    const hot = conditions.filter((c) => band(c) === 'hot').length;
    const cold = conditions.filter((c) => band(c) === 'cold').length;
    if (hot * 2 > conditions.length) s += warmth === 0 ? 1.2 : (warmth === 2 ? -1.5 : 0);
    if (cold * 2 > conditions.length) s += warmth === 2 ? 1.2 : (warmth === 0 ? -1.2 : 0);
  }
  if (item.formality === 'formal' || item.formality === 'smart') s += occasions.has('work') || occasions.has('evening') ? 0.8 : -0.2;
  else if (item.formality === 'sporty') s += occasions.has('sport') ? 0.8 : -0.3;
  else if (item.formality === 'casual') s += occasions.has('everyday') ? 0.3 : 0;
  if (item.favorite) s += 0.5;
  s += (liking.get(up(item.id)) ?? 0) * 0.3;
  if (item.stored) s -= 0.4;
  return s;
}

const PACKING_ORDER = ['top', 'bottom', 'dress', 'outerwear', 'shoes', 'bag', 'accessory'];
// As shown: pieces of the kind Other can be put in by hand too.
const LINE_ORDER = ['ski', ...PACKING_ORDER, 'other'];

const tripOccasions = (trip) => new Set(trip.occasions?.length ? trip.occasions : ['everyday']);
const tripConditions = (trip) => (trip.days ?? []).map(conditionsOf).filter(Boolean);
export const tripDays = (trip) => Math.max(1, (trip.nights ?? 0) + 1);

/** The pieces for a trip: for each kind, the ones that suit the weather and the occasions best. */
export function packingPlan(items, trip, wears = [], name = (item) => item.name ?? '') {
  const conditions = tripConditions(trip);
  const occasions = tripOccasions(trip);
  const wanted = packingCounts({ days: tripDays(trip), conditions, occasions, items });
  const liking = affinity(wears);
  // To the snow goes all the ski gear: it is one kit, not a choice among many.
  const gear = trip.ski ? items.filter(apart).map((i) => i.id) : [];
  return gear.concat(PACKING_ORDER.flatMap((category) => {
    const options = items.filter((i) => i.category === category);
    if (!wanted[category] || !options.length) return [];
    const best = options
      .map((item) => ({ item, fit: packingFit(item, conditions, occasions, liking) }))
      .sort((a, b) => b.fit - a.fit || name(a.item).localeCompare(name(b.item)));
    return best.slice(0, wanted[category]).map((e) => e.item.id);
  }));
}

/** The suitcase as it is shown: for each kind how many are needed and the pieces chosen. Packed
 * by hand there is no count to reach: a kind shows when it has pieces. */
export function packingLines(items, trip) {
  const wanted = trip.manual ? {} : packingCounts({ days: tripDays(trip), conditions: tripConditions(trip), occasions: tripOccasions(trip), items });
  const byID = new Map(items.map((i) => [up(i.id), i]));
  const chosen = (trip.chosen ?? []).map((id) => byID.get(up(id))).filter(Boolean);
  return LINE_ORDER.flatMap((category) => {
    const pieces = chosen.filter((p) => p.category === category);
    const count = wanted[category] ?? (pieces.length || null);
    return count ? [{ category, count, items: pieces }] : [];
  });
}

/** Things that are not in the closet but go in the suitcase: [text, number] to be translated. */
export function packingReminders(trip) {
  const conditions = tripConditions(trip);
  const out = [['Biancheria e calze:', tripDays(trip) + 1], ['Pigiama'], ['Caricabatterie e documenti']];
  if (conditions.some(rainy)) out.push(['Ombrello: è prevista pioggia']);
  if (conditions.some((c) => band(c) === 'hot')) out.push(['Occhiali da sole e crema solare']);
  if (conditions.some((c) => band(c) === 'cold')) out.push(['Sciarpa, guanti e berretto']);
  if (trip.ski) out.push(['Skipass, crema solare e burrocacao'], ['Scaldacollo e calze termiche di ricambio']);
  if ((trip.occasions ?? []).includes('sport')) out.push(['Calze e borraccia per lo sport']);
  if ((trip.nights ?? 0) > 7) out.push(['Un sacchetto per i panni sporchi: oltre una settimana conviene un lavaggio']);
  return out;
}

// ---------- the stylist ----------

/** The pieces named as [n] in an answer of the AI, each once, in order. */
export function mentioned(text, items) {
  const out = [];
  for (const match of String(text).matchAll(/\[(\d{1,3})\]/g)) {
    const item = items[Number(match[1]) - 1];
    if (item && !out.includes(item)) out.push(item);
  }
  return out;
}

/** "[3]" becomes the name of piece 3, so the answer reads well. */
export function readable(text, items, name) {
  return String(text).replace(/\s?\[(\d{1,3})\]/g, (whole, n, at, all) => {
    const item = items[Number(n) - 1];
    if (!item) return whole;
    const label = name(item);
    // Already written by the AI just before: drop the number only.
    return all.slice(Math.max(0, at - label.length - 2), at).toLowerCase().includes(label.toLowerCase()) ? '' : ` (${label})`;
  });
}

// ---------- the numbers ----------

const counted = (object) => Object.entries(object).map(([key, count]) => ({ key, count })).sort((a, b) => b.count - a.count || a.key.localeCompare(b.key));
const priced = (item) => (typeof item.price === 'number' && item.price > 0 ? item.price : 0);

/** The numbers of the closet and the diary, for all time (`since` null) or from a day on. */
export function stats(items, wears, since = null, name = (item) => item.name ?? '') {
  const period = wears.filter((w) => !since || w.day >= since);
  const byID = new Map(items.map((i) => [up(i.id), i]));
  const times = wornDays(period);
  const allTimes = wornDays(wears);
  const categories = {};
  const colors = {};
  const worn = [];
  for (const [key, days] of times) {
    const item = byID.get(key);
    if (!item) continue;
    categories[item.category] = (categories[item.category] ?? 0) + days.size;
    if (item.colors?.[0]) colors[item.colors[0]] = (colors[item.colors[0]] ?? 0) + days.size;
    worn.push({ item, times: days.size });
  }
  const owned = {};
  for (const item of items) if (item.colors?.[0]) owned[item.colors[0]] = (owned[item.colors[0]] ?? 0) + 1;
  worn.sort((a, b) => b.times - a.times || name(a.item).localeCompare(name(b.item)));
  return {
    pieces: items.length,
    daysWritten: new Set(period.map((w) => w.day)).size,
    wornPieces: worn.length,
    neverWorn: items.filter((i) => !(allTimes.get(up(i.id))?.size)),
    byCategory: counted(categories),
    byColor: counted(colors),
    closetColors: counted(owned),
    mostWorn: worn.slice(0, 5),
    liked: [...affinity(wears)].filter(([, v]) => v > 0).sort((a, b) => b[1] - a[1]).map(([k]) => byID.get(k)).filter(Boolean).slice(0, 5),
    closetValue: items.reduce((sum, i) => sum + (typeof i.price === 'number' ? i.price : 0), 0),
    costPerWear: items.filter((i) => priced(i)).map((item) => {
      const n = allTimes.get(up(item.id))?.size ?? 0;
      return { item, times: n, cost: n ? item.price / n : item.price };
    }).sort((a, b) => b.cost - a.cost),
  };
}

/** What was spent month by month, the last `months` to `today`: the price of each piece in the
 * month it came into the closet. */
export function spending(items, months = 12, today = new Date()) {
  const out = [];
  for (let i = months - 1; i >= 0; i -= 1) {
    const first = new Date(today.getFullYear(), today.getMonth() - i, 1);
    out.push({ month: dayKey(first).slice(0, 7), total: 0, pieces: 0 });
  }
  const byMonth = new Map(out.map((m) => [m.month, m]));
  for (const item of items) {
    if (!priced(item) || !item.created) continue;
    const month = byMonth.get(dayKey(new Date(item.created)).slice(0, 7));
    if (!month) continue;
    month.total += item.price;
    month.pieces += 1;
  }
  return out;
}

/** Pieces in the closet for more than `days` and never worn, the dearest first, and what they cost. */
export function idle(items, wears, days = 60, today = new Date()) {
  const limit = addDays(today, -days);
  const worn = wornDays(wears);
  const list = items
    .filter((i) => !apart(i) && !worn.get(up(i.id))?.size && i.created && new Date(i.created) < limit)
    .sort((a, b) => priced(b) - priced(a) || String(a.created).localeCompare(String(b.created)));
  return { items: list, value: list.reduce((sum, i) => sum + priced(i), 0) };
}

/** The years that have something to tell: the ones with days in the diary, the latest first. */
export function recapYears(wears) {
  return [...new Set(wears.map((w) => Number(String(w.day).slice(0, 4))).filter((y) => y > 2000))].sort((a, b) => b - a);
}

/** A year in a few numbers, to look back on and to share. */
export function yearRecap(items, outfits, wears, year, name = (item) => item.name ?? '') {
  const prefix = `${year}-`;
  const period = wears.filter((w) => String(w.day).startsWith(prefix));
  const byID = new Map(items.map((i) => [up(i.id), i]));
  const times = wornDays(period);
  const worn = [...times].map(([key, days]) => ({ item: byID.get(key), times: days.size })).filter((e) => e.item)
    .sort((a, b) => b.times - a.times || name(a.item).localeCompare(name(b.item)));
  const colors = {};
  for (const e of worn) if (e.item.colors?.[0]) colors[e.item.colors[0]] = (colors[e.item.colors[0]] ?? 0) + e.times;
  const outfitTimes = new Map();
  for (const wear of period) if (wear.outfit) {
    const k = up(wear.outfit);
    if (!outfitTimes.has(k)) outfitTimes.set(k, new Set());
    outfitTimes.get(k).add(wear.day);
  }
  const topOutfit = [...outfitTimes].map(([key, days]) => ({ outfit: outfits.find((o) => up(o.id) === key), times: days.size }))
    .filter((e) => e.outfit).sort((a, b) => b.times - a.times)[0] ?? null;
  const added = items.filter((i) => i.created && new Date(i.created).getFullYear() === year);
  // The piece that paid for itself best: the lowest cost per wear, with the wears of this year.
  const best = worn.filter((e) => priced(e.item)).map((e) => ({ ...e, cost: e.item.price / e.times })).sort((a, b) => a.cost - b.cost)[0] ?? null;
  return {
    year,
    days: new Set(period.map((w) => w.day)).size,
    wornPieces: worn.length,
    pieces: items.length,
    mostWorn: worn.slice(0, 3),
    colors: counted(colors).slice(0, 5),
    topOutfit,
    added: added.length,
    spent: added.reduce((sum, i) => sum + priced(i), 0),
    best,
  };
}
