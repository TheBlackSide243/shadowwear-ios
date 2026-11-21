// The weather for the web site, from Open-Meteo (free, no account, no key). The page may only talk
// to this server, so the server asks for it. All Open-Meteo is sent is the name of a town being
// searched, or a position rounded to about a kilometre, as the iPhone app does.

const SEARCH = 'https://geocoding-api.open-meteo.com/v1/search';
const FORECAST = 'https://api.open-meteo.com/v1/forecast';
const DAY = /^\d{4}-\d{2}-\d{2}$/;

/** A latitude or longitude from the address of a request, or null when it is not one. */
export function coordinate(text, limit) {
  if (typeof text !== 'string' || !/^-?\d{1,3}(\.\d{1,8})?$/.test(text)) return null;
  const value = Number(text);
  return Math.abs(value) <= limit ? Math.round(value * 100) / 100 : null;
}

export function isDay(text) {
  return typeof text === 'string' && DAY.test(text) && !Number.isNaN(Date.parse(`${text}T00:00:00Z`));
}

/** The day `n` days after `day` (both yyyy-MM-dd). */
export function dayAfter(day, n) {
  return new Date(Date.parse(`${day}T00:00:00Z`) + n * 86_400_000).toISOString().slice(0, 10);
}

export class Weather {
  constructor(fetcher = fetch) {
    this.fetch = fetcher;
    // The same question within half an hour is answered from here.
    this.cache = new Map();
  }

  async ask(base, query) {
    const url = `${base}?${new URLSearchParams(query)}`;
    const kept = this.cache.get(url);
    if (kept && Date.now() - kept.at < 30 * 60_000) return kept.data;
    const res = await this.fetch(url, { signal: AbortSignal.timeout(10_000) });
    if (!res.ok) throw new Error(`Open-Meteo ${res.status}`);
    const data = await res.json();
    if (this.cache.size >= 200) this.cache.delete(this.cache.keys().next().value);
    this.cache.set(url, { at: Date.now(), data });
    return data;
  }

  /** Towns matching a name: "Lisbona, Portogallo" with where they are. */
  async places(name, language = 'it') {
    const query = String(name ?? '').trim().slice(0, 80);
    if (query.length < 2) return [];
    const data = await this.ask(SEARCH, { name: query, count: '8', language: language === 'en' ? 'en' : 'it', format: 'json' });
    return (data.results ?? []).filter((r) => typeof r.latitude === 'number' && typeof r.longitude === 'number').map((r) => {
      const detail = [r.admin1, r.country].filter((d) => d && d !== r.name);
      return {
        name: [r.name, ...detail.slice(0, 1)].join(', '),
        latitude: Math.round(r.latitude * 100) / 100,
        longitude: Math.round(r.longitude * 100) / 100,
      };
    });
  }

  /** Today's weather at a place: now, the highest and lowest, the chance of rain and the sky. */
  async today(latitude, longitude) {
    const data = await this.ask(FORECAST, {
      latitude: latitude.toFixed(2), longitude: longitude.toFixed(2),
      current: 'temperature_2m,weather_code',
      daily: 'temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code',
      timezone: 'auto', forecast_days: '1',
    });
    const daily = data.daily ?? {};
    const high = daily.temperature_2m_max?.[0];
    const low = daily.temperature_2m_min?.[0];
    if (typeof high !== 'number' || typeof low !== 'number') throw new Error('Open-Meteo: no temperatures');
    return {
      day: daily.time?.[0] ?? null,
      now: typeof data.current?.temperature_2m === 'number' ? data.current.temperature_2m : null,
      high, low,
      rain: daily.precipitation_probability_max?.[0] ?? 0,
      code: daily.weather_code?.[0] ?? data.current?.weather_code ?? 3,
    };
  }

  /**
   * The forecast of each day of a trip, as far as it is known (16 days from `today`, the day of
   * whoever asks). Days further away come back without temperatures.
   */
  async trip(latitude, longitude, start, days, today) {
    const keys = Array.from({ length: Math.max(1, Math.min(days, 40)) }, (_, i) => dayAfter(start, i));
    const horizon = dayAfter(today, 15);
    const first = keys[0];
    const last = keys[keys.length - 1];
    if (first > horizon || last < today) return keys.map((day) => ({ day }));
    const data = await this.ask(FORECAST, {
      latitude: latitude.toFixed(2), longitude: longitude.toFixed(2),
      daily: 'temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      timezone: 'auto',
      start_date: first > today ? first : today,
      end_date: last < horizon ? last : horizon,
    });
    const daily = data.daily ?? {};
    const known = new Map();
    (daily.time ?? []).forEach((day, i) => {
      const high = daily.temperature_2m_max?.[i];
      const low = daily.temperature_2m_min?.[i];
      if (typeof high !== 'number' || typeof low !== 'number') return;
      known.set(day, { day, high, low, rain: daily.precipitation_probability_max?.[i] ?? 0 });
    });
    return keys.map((day) => known.get(day) ?? { day });
  }
}
