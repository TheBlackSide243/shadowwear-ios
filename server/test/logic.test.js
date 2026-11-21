import test from 'node:test';
import assert from 'node:assert/strict';
import {
  band, clearOut, dayDistance, dayKey, idle, laundry, mentioned, packingCounts, packingLines, packingPlan,
  packingReminders, readable, recapYears, seasonOf, seasonSwap, seasonsOf, seedFor, spending, stats, suggestions,
  washEvery, wearsSinceWash, yearRecap,
} from '../web/logic.mjs';

const id = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const piece = (n, category, more = {}) => ({ id: id(n), name: `${category} ${n}`, category, colors: [], created: '2026-01-10T10:00:00.000Z', ...more });
const worn = (day, items, more = {}) => ({ id: id(9000 + Number(day.replaceAll('-', '')) % 1000), day, items: items.map((i) => i.id), ...more });
const today = new Date(2026, 10, 21);

test('days: the key of a day and the days between two', () => {
  assert.equal(dayKey(new Date(2026, 0, 5)), '2026-01-05');
  assert.equal(dayDistance('2026-11-21', today), 0);
  assert.equal(dayDistance('2026-11-14', today), 7);
  assert.equal(dayDistance('nonsense', today), null);
});

test('the weather band leans on the highest temperature', () => {
  assert.equal(band({ high: 8, low: 0 }), 'cold');
  assert.equal(band({ high: 16, low: 8 }), 'cool');
  assert.equal(band({ high: 24, low: 14 }), 'mild');
  assert.equal(band({ high: 31, low: 20 }), 'hot');
});

test('seasons: of a date, of a piece, and what to put away', () => {
  assert.equal(seasonOf(new Date(2026, 6, 1)), 'summer');
  assert.equal(seasonOf(new Date(2026, 6, 1), true), 'winter');
  assert.deepEqual([...seasonsOf(piece(1, 'outerwear'))], ['autumn', 'winter']);
  assert.deepEqual([...seasonsOf(piece(1, 'top', { warmth: 0 }))], ['spring', 'summer']);
  assert.deepEqual([...seasonsOf(piece(1, 'top', { warmth: 0, seasons: ['winter', 'whatever'] }))], ['winter']);
  const linen = piece(1, 'top', { warmth: 0 });
  const coat = piece(2, 'outerwear', { stored: true });
  const tee = piece(3, 'top');
  const swap = seasonSwap([linen, coat, tee], today);
  assert.equal(swap.season, 'autumn');
  assert.deepEqual(swap.putAway.map((i) => i.id), [linen.id]);
  assert.deepEqual(swap.bringOut.map((i) => i.id), [coat.id]);
});

test('washing: a top after two days, counted from the last wash', () => {
  const tee = piece(1, 'top');
  const shoes = piece(2, 'shoes');
  const wears = [worn('2026-11-10', [tee, shoes]), worn('2026-11-12', [tee, shoes]), { ...worn('2026-11-12', [tee]), id: id(77) }];
  assert.equal(washEvery(tee), 2);
  assert.equal(washEvery(shoes), null);
  assert.equal(washEvery({ ...tee, washEvery: 0 }), null);
  assert.equal(wearsSinceWash(tee, wears), 2);
  assert.deepEqual(laundry([tee, shoes], wears).map((e) => e.item.id), [tee.id]);
  // Washed on the 11th: only the 12th counts.
  const washed = { ...tee, washed: new Date(2026, 10, 11, 20).toISOString() };
  assert.equal(wearsSinceWash(washed, wears), 1);
  assert.deepEqual(laundry([washed], wears), []);
});

test('clear-out: not worn for months, or never since long; not what is put away or kept', () => {
  const old = piece(1, 'top');
  const recent = piece(2, 'top');
  const never = piece(3, 'bottom', { created: '2025-01-01T10:00:00.000Z' });
  const fresh = piece(4, 'bottom', { created: '2026-11-01T10:00:00.000Z' });
  const stored = piece(5, 'top', { created: '2025-01-01T10:00:00.000Z', stored: true });
  const kept = piece(6, 'top', { created: '2025-01-01T10:00:00.000Z', keepUntil: '2027-01-01T10:00:00.000Z' });
  const wears = [worn('2026-02-01', [old]), worn('2026-11-01', [recent])];
  const list = clearOut([old, recent, never, fresh, stored, kept], wears, 6, today);
  assert.deepEqual(list.map((e) => e.item.id), [never.id, old.id]);
  assert.equal(list[1].lastWorn, '2026-02-01');
  assert.equal(list[1].times, 1);
});

test('the idea of the day: the same for the same seed, a coat when it is cold, nothing put away', () => {
  const items = [piece(1, 'top'), piece(2, 'top'), piece(3, 'bottom'), piece(4, 'outerwear'), piece(5, 'shoes'), piece(6, 'top', { stored: true })];
  const ask = (seed, conditions) => suggestions({ items, outfits: [], wears: [], conditions, today, seed });
  const cold = ask(seedFor('2026-11-21'), { high: 5, low: -1, rain: 10 });
  assert.ok(cold.length >= 1);
  assert.deepEqual(cold, ask(seedFor('2026-11-21'), { high: 5, low: -1, rain: 10 }));
  for (const idea of cold) {
    assert.ok(idea.items.includes(items[3].id), 'a coat when it is cold');
    assert.ok(!idea.items.includes(items[5].id), 'nothing put away');
  }
  // The same pieces only once.
  assert.equal(new Set(cold.map((i) => [...i.items].sort().join())).size, cold.length);
  // Nothing to make an outfit with: no ideas.
  assert.deepEqual(suggestions({ items: [piece(1, 'shoes')], outfits: [], wears: [], seed: 1 }), []);
});

test('the idea of the day: a saved outfit worn yesterday goes after the others', () => {
  const items = [piece(1, 'top'), piece(2, 'bottom'), piece(3, 'top'), piece(4, 'bottom')];
  const outfits = [{ id: id(100), name: 'Ufficio', items: [items[0].id, items[1].id], favorite: true }];
  const fresh = suggestions({ items, outfits, wears: [], today, seed: 3 });
  assert.equal(fresh[0].outfit, outfits[0].id);
  const wears = [{ ...worn('2026-11-20', [items[0], items[1]]), outfit: outfits[0].id }];
  const after = suggestions({ items, outfits, wears, today, seed: 3 });
  assert.notEqual(after[0].outfit, outfits[0].id);
});

test('the suitcase: how many of each kind, the best pieces, what not to forget', () => {
  const items = [1, 2, 3, 4, 5, 6].map((n) => piece(n, 'top')).concat([piece(10, 'bottom'), piece(11, 'bottom'), piece(20, 'outerwear'), piece(30, 'shoes'), piece(31, 'shoes'), piece(40, 'dress')]);
  const cold = [{ high: 4, low: -2, rain: 80 }];
  const counts = packingCounts({ days: 4, conditions: cold, occasions: new Set(['everyday', 'evening']), items });
  assert.deepEqual(counts, { top: 4, bottom: 2, dress: 1, outerwear: 1, shoes: 2, bag: 1, accessory: 2 });
  assert.equal(packingCounts({ days: 3, conditions: [{ high: 30, low: 20, rain: 0 }], occasions: new Set(['everyday']), items }).outerwear, undefined);

  const trip = { nights: 3, occasions: ['everyday'], days: [{ day: '2026-12-01', high: 4, low: -2, rain: 80 }, { day: '2026-12-02' }] };
  const favourite = { ...items[5], favorite: true };
  const chosen = packingPlan(items.map((i) => (i.id === favourite.id ? favourite : i)), trip);
  assert.equal(chosen[0], favourite.id);
  assert.equal(chosen.filter((c) => items.find((i) => i.id === c).category === 'top').length, 4);
  const lines = packingLines(items, { ...trip, chosen: [items[0].id, items[6].id] });
  assert.deepEqual(lines.map((l) => [l.category, l.count, l.items.length]).slice(0, 2), [['top', 4, 1], ['bottom', 2, 1]]);
  const reminders = packingReminders(trip).map(([text]) => text);
  assert.deepEqual(packingReminders(trip)[0], ['Biancheria e calze:', 5]);
  assert.ok(reminders.includes('Ombrello: è prevista pioggia'));
  assert.ok(reminders.includes('Sciarpa, guanti e berretto'));
});

test('the stylist: the pieces it names by number', () => {
  const items = [piece(1, 'top', { name: 'Camicia bianca' }), piece(2, 'bottom', { name: 'Jeans' })];
  const text = 'Metti la camicia bianca [1] con [2] e [9].';
  assert.deepEqual(mentioned(text, items).map((i) => i.id), [items[0].id, items[1].id]);
  assert.equal(readable(text, items, (i) => i.name), 'Metti la camicia bianca con (Jeans) e [9].');
});

test('the numbers: what is worn, the colors, the cost per wear', () => {
  const shirt = piece(1, 'top', { colors: ['white'], price: 40 });
  const jeans = piece(2, 'bottom', { colors: ['blue'], price: 90 });
  const coat = piece(3, 'outerwear', { colors: ['navy'], price: 200 });
  const wears = [worn('2026-10-01', [shirt, jeans], { rating: 1 }), worn('2026-11-01', [shirt])];
  const all = stats([shirt, jeans, coat], wears);
  assert.equal(all.pieces, 3);
  assert.equal(all.daysWritten, 2);
  assert.equal(all.wornPieces, 2);
  assert.deepEqual(all.neverWorn.map((i) => i.id), [coat.id]);
  assert.deepEqual(all.byCategory, [{ key: 'top', count: 2 }, { key: 'bottom', count: 1 }]);
  assert.deepEqual(all.mostWorn.map((e) => e.times), [2, 1]);
  assert.equal(all.closetValue, 330);
  assert.deepEqual(all.costPerWear.map((e) => [e.item.id, e.cost]), [[coat.id, 200], [jeans.id, 90], [shirt.id, 20]]);
  assert.deepEqual(all.liked.map((i) => i.id).sort(), [shirt.id, jeans.id].sort());
  assert.equal(stats([shirt, jeans, coat], wears, '2026-10-15').daysWritten, 1);
});

test('spending by month: the price of a piece in the month it came in', () => {
  const items = [
    piece(1, 'top', { price: 30, created: '2026-11-03T10:00:00.000Z' }),
    piece(2, 'top', { price: 20.5, created: '2026-11-20T10:00:00.000Z' }),
    piece(3, 'top', { price: 100, created: '2026-09-15T10:00:00.000Z' }),
    piece(4, 'top', { created: '2026-10-15T10:00:00.000Z' }),
    piece(5, 'top', { price: 999, created: '2020-10-15T10:00:00.000Z' }),
  ];
  const months = spending(items, 3, today);
  assert.deepEqual(months, [
    { month: '2026-09', total: 100, pieces: 1 },
    { month: '2026-10', total: 0, pieces: 0 },
    { month: '2026-11', total: 50.5, pieces: 2 },
  ]);
  assert.equal(spending(items, 12, today).length, 12);
});

test('bought and never worn: in the closet for more than 60 days, the dearest first', () => {
  const old = piece(1, 'top', { price: 30, created: '2026-06-01T10:00:00.000Z' });
  const dear = piece(2, 'outerwear', { price: 180, created: '2026-08-01T10:00:00.000Z' });
  const wornOnce = piece(3, 'top', { price: 60, created: '2026-06-01T10:00:00.000Z' });
  const fresh = piece(4, 'top', { price: 70, created: '2026-11-01T10:00:00.000Z' });
  const found = idle([old, dear, wornOnce, fresh], [worn('2026-07-01', [wornOnce])], 60, today);
  assert.deepEqual(found.items.map((i) => i.id), [dear.id, old.id]);
  assert.equal(found.value, 210);
});

test('the year in a few numbers', () => {
  const shirt = piece(1, 'top', { colors: ['white'], price: 40, created: '2026-03-01T10:00:00.000Z' });
  const jeans = piece(2, 'bottom', { colors: ['blue'], price: 90, created: '2025-03-01T10:00:00.000Z' });
  const outfit = { id: id(100), name: 'Ufficio', items: [shirt.id, jeans.id] };
  const wears = [
    { ...worn('2026-10-01', [shirt, jeans]), outfit: outfit.id },
    { ...worn('2026-10-02', [shirt, jeans]), outfit: outfit.id },
    worn('2026-11-01', [shirt]),
    worn('2025-11-01', [jeans]),
  ];
  assert.deepEqual(recapYears(wears), [2026, 2025]);
  const year = yearRecap([shirt, jeans], [outfit], wears, 2026);
  assert.equal(year.days, 3);
  assert.equal(year.wornPieces, 2);
  assert.deepEqual(year.mostWorn.map((e) => [e.item.id, e.times]), [[shirt.id, 3], [jeans.id, 2]]);
  assert.deepEqual(year.colors, [{ key: 'white', count: 3 }, { key: 'blue', count: 2 }]);
  assert.equal(year.topOutfit.outfit.id, outfit.id);
  assert.equal(year.topOutfit.times, 2);
  assert.equal(year.added, 1);
  assert.equal(year.spent, 40);
  assert.equal(year.best.item.id, shirt.id);
  assert.ok(Math.abs(year.best.cost - 40 / 3) < 1e-9);
  assert.equal(yearRecap([shirt, jeans], [outfit], wears, 2024).days, 0);
});
