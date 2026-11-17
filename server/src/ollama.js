// The AI of the user's own server: Ollama, asked to look at a photo and describe the piece.
// Nothing leaves the house. The model is chosen in the web settings (it must see images).

export const CATEGORIES = ['top', 'bottom', 'dress', 'outerwear', 'shoes', 'bag', 'accessory', 'other'];
export const COLORS = ['black', 'white', 'grey', 'beige', 'brown', 'red', 'burgundy', 'pink', 'orange', 'yellow',
  'olive', 'green', 'lightblue', 'blue', 'navy', 'purple'];
const WARMTH = { light: 0, medium: 1, warm: 2 };

const SCHEMA = {
  type: 'object',
  properties: {
    name: { type: 'string' },
    category: { type: 'string', enum: CATEGORIES },
    colors: { type: 'array', items: { type: 'string', enum: COLORS } },
    warmth: { type: 'string', enum: Object.keys(WARMTH) },
    material: { type: 'string' },
    style: { type: 'string' },
    notes: { type: 'string' },
  },
  required: ['name', 'category', 'colors', 'warmth'],
};

function prompt(language) {
  const it = language !== 'en';
  return [
    it
      ? 'Guarda la foto: c\'è un capo di abbigliamento (o scarpe, borsa, accessorio). Descrivilo per un armadio digitale.'
      : 'Look at the photo: there is a piece of clothing (or shoes, a bag, an accessory). Describe it for a digital closet.',
    it
      ? 'Rispondi solo in JSON con: name (nome breve in italiano, 2-4 parole, es. "Felpa grigia con cappuccio"), category, colors (1-3, il principale per primo), warmth (light, medium o warm: quanto tiene caldo), material, style (es. casual, elegante, sportivo), notes (una frase: con cosa abbinarlo o come lavarlo).'
      : 'Answer only in JSON with: name (short English name, 2-4 words, e.g. "Grey hooded sweatshirt"), category, colors (1-3, the main one first), warmth (light, medium or warm), material, style (e.g. casual, smart, sporty), notes (one sentence: what it goes with or how to wash it).',
    `category: ${CATEGORIES.join(', ')}. colors: ${COLORS.join(', ')}.`,
  ].join('\n');
}

export class Ollama {
  constructor(url, fetcher = fetch) {
    this.url = (url || '').replace(/\/+$/, '');
    this.fetch = fetcher;
  }

  get configured() {
    return Boolean(this.url);
  }

  async call(pathname, body, timeout = 120_000) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeout);
    try {
      const response = await this.fetch(`${this.url}${pathname}`, {
        method: body ? 'POST' : 'GET',
        headers: body ? { 'content-type': 'application/json' } : undefined,
        body: body ? JSON.stringify(body) : undefined,
        signal: controller.signal,
      });
      if (!response.ok) throw new Error(`Ollama ${response.status}: ${(await response.text()).slice(0, 200)}`);
      return await response.json();
    } finally {
      clearTimeout(timer);
    }
  }

  /** The models Ollama has, with whether each can see images. */
  async models() {
    const tags = await this.call('/api/tags', null, 10_000);
    const out = [];
    for (const model of tags.models ?? []) {
      let vision = false;
      try {
        const info = await this.call('/api/show', { model: model.name }, 10_000);
        vision = (info.capabilities ?? []).includes('vision') || Boolean(info.projector_info);
      } catch {
        // An older Ollama without capabilities: leave it unknown (false).
      }
      out.push({ name: model.name, size: model.size, vision });
    }
    return out;
  }

  /** A question of the app, with a photo or not; the answer as text (JSON when asked). */
  async chat(model, { system = '', prompt, image = null, json = false }) {
    const messages = [];
    if (system) messages.push({ role: 'system', content: system });
    const user = { role: 'user', content: prompt };
    if (image) user.images = [image.toString('base64')];
    messages.push(user);
    const answer = await this.call('/api/chat', {
      model,
      stream: false,
      ...(json ? { format: 'json' } : {}),
      keep_alive: '5m',
      options: { temperature: json ? 0.2 : 0.6 },
      messages,
    }, 240_000);
    const text = answer?.message?.content;
    if (typeof text !== 'string' || !text.trim()) throw new Error('risposta vuota');
    return text.trim();
  }

  /** What the piece in the photo is: name, kind, colors, warmth and a few words. */
  async describe(model, image, language = 'it') {
    if (!model) throw new Error('Nessun modello scelto: sceglilo nelle impostazioni del sito.');
    const answer = await this.call('/api/chat', {
      model,
      stream: false,
      format: SCHEMA,
      keep_alive: '5m',
      options: { temperature: 0.2 },
      messages: [{ role: 'user', content: prompt(language), images: [image.toString('base64')] }],
    });
    return clean(answer?.message?.content);
  }
}

/** The model's JSON, kept to what the app understands. */
export function clean(text) {
  let raw;
  try {
    raw = typeof text === 'string' ? JSON.parse(text) : text;
  } catch {
    const match = String(text ?? '').match(/\{[\s\S]*\}/);
    raw = match ? JSON.parse(match[0]) : {};
  }
  const str = (v, n) => (typeof v === 'string' ? v.trim().slice(0, n) : '');
  const colors = Array.isArray(raw.colors) ? [...new Set(raw.colors.map((c) => String(c).toLowerCase()))].filter((c) => COLORS.includes(c)).slice(0, 3) : [];
  return {
    name: str(raw.name, 60),
    category: CATEGORIES.includes(raw.category) ? raw.category : 'other',
    colors,
    warmth: WARMTH[raw.warmth] ?? null,
    material: str(raw.material, 60),
    style: str(raw.style, 60),
    notes: str(raw.notes, 300),
  };
}
