// The AI of the user's own server: Ollama, asked to look at a photo and describe the piece.
// Nothing leaves the house. Its address and the model are chosen in the web settings (the
// address can also come from OLLAMA_URL); each iPhone may ask for another model of the same Ollama.

export const CATEGORIES = ['top', 'bottom', 'dress', 'outerwear', 'shoes', 'bag', 'accessory', 'ski', 'other'];
export const COLORS = ['black', 'white', 'grey', 'beige', 'brown', 'red', 'burgundy', 'pink', 'orange', 'yellow',
  'olive', 'green', 'lightblue', 'blue', 'navy', 'purple'];
const WARMTH = { light: 0, medium: 1, warm: 2 };
// Color words some models write instead of the keys, in Italian or English.
const COLOR_WORDS = {
  nero: 'black', nera: 'black', neri: 'black', nere: 'black',
  bianco: 'white', bianca: 'white', bianchi: 'white', bianche: 'white', panna: 'white',
  grigio: 'grey', grigia: 'grey', grigi: 'grey', grigie: 'grey', gray: 'grey', antracite: 'grey',
  sabbia: 'beige', cammello: 'beige', camel: 'beige', crema: 'beige', cream: 'beige',
  marrone: 'brown', marroni: 'brown', cuoio: 'brown',
  rosso: 'red', rossa: 'red', rossi: 'red', rosse: 'red',
  bordò: 'burgundy', maroon: 'burgundy',
  fucsia: 'pink', arancio: 'orange', arancione: 'orange', arancioni: 'orange',
  giallo: 'yellow', gialla: 'yellow', gialli: 'yellow', gialle: 'yellow', senape: 'yellow',
  oliva: 'olive', 'verde oliva': 'olive', kaki: 'olive', khaki: 'olive', 'verde militare': 'olive',
  verde: 'green', verdi: 'green',
  azzurro: 'lightblue', azzurra: 'lightblue', azzurri: 'lightblue', azzurre: 'lightblue', celeste: 'lightblue', 'light blue': 'lightblue',
  blu: 'blue', denim: 'blue',
  'blu scuro': 'navy', 'blu navy': 'navy', 'dark blue': 'navy',
  viola: 'purple', lilla: 'purple', lavanda: 'purple', violet: 'purple',
};
const colorKey = (word) => {
  const w = String(word).trim().toLowerCase();
  return COLORS.includes(w) ? w : COLOR_WORDS[w];
};

const SCHEMA = {
  type: 'object',
  properties: {
    name: { type: 'string' },
    // Right after the name, and required: otherwise the model writes the brand in the name and leaves this out.
    brand: { type: 'string' },
    size: { type: 'string' },
    category: { type: 'string', enum: CATEGORIES },
    colors: { type: 'array', items: { type: 'string', enum: COLORS } },
    warmth: { type: 'string', enum: Object.keys(WARMTH) },
    material: { type: 'string' },
    style: { type: 'string' },
    notes: { type: 'string' },
  },
  required: ['name', 'brand', 'size', 'category', 'colors', 'warmth'],
};

function prompt(language) {
  const it = language !== 'en';
  return [
    it
      ? 'Guarda la foto: c\'è un capo di abbigliamento (o scarpe, borsa, accessorio). Descrivilo per un armadio digitale.'
      : 'Look at the photo: there is a piece of clothing (or shoes, a bag, an accessory). Describe it for a digital closet.',
    it
      ? 'Rispondi solo in JSON con: name (nome breve in italiano, 2-4 parole, che comincia con il tipo preciso: T-shirt, polo, camicia, felpa, maglione, jeans, chino, gonna, sneakers, stivaletti, zaino…; es. "T-shirt bianca con stampa", "Felpa grigia con cappuccio"), category, colors (1-3, il principale per primo), warmth (light, medium o warm: quanto tiene caldo), material, style (es. casual, elegante, sportivo), notes (una frase: con cosa abbinarlo o come lavarlo), brand (la marca, solo se la leggi su un logo, una stampa o un’etichetta nella foto, altrimenti ""), size (la taglia, solo se la leggi su un’etichetta, altrimenti ""). Non indovinare mai la marca dallo stile.'
      : 'Answer only in JSON with: name (short English name, 2-4 words, starting with the exact kind: T-shirt, polo, shirt, sweatshirt, jumper, jeans, chinos, skirt, sneakers, boots, backpack…; e.g. "White printed T-shirt", "Grey hooded sweatshirt"), category, colors (1-3, the main one first), warmth (light, medium or warm), material, style (e.g. casual, smart, sporty), notes (one sentence: what it goes with or how to wash it), brand (only when you can read it on a logo, a print or a label in the photo, otherwise ""), size (only when you can read it on a label, otherwise ""). Never guess a brand from the style.',
    `category: ${CATEGORIES.join(', ')}. colors: ${COLORS.join(', ')}.`,
  ].join('\n');
}

export class Ollama {
  constructor(url, fetcher = fetch) {
    this.fetch = fetcher;
    /** Models that refused `think: false` (an Ollama without it): asked without from then on. */
    this.thinking = new Set();
    this.setURL(url);
  }

  setURL(url) {
    this.url = (url || '').replace(/\/+$/, '');
  }

  /** An address the user typed, as Ollama's base ("192.168.1.10:11434" → "http://192.168.1.10:11434"),
   * or null when it is not an http(s) address. */
  static normalize(text) {
    let value = String(text ?? '').trim();
    if (!value) return '';
    if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(value)) value = `http://${value}`;
    let parsed;
    try {
      parsed = new URL(value);
    } catch {
      return null;
    }
    if (!['http:', 'https:'].includes(parsed.protocol) || !parsed.hostname || value.length > 300) return null;
    // Ollama's own paths are added by the server: an address copied with /api or /v1 still works.
    const pathname = parsed.pathname.replace(/\/(api|v1)\/?$/, '').replace(/\/+$/, '');
    return `${parsed.protocol}//${parsed.host}${pathname}`;
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
      if (!response.ok) {
        const error = new Error(`Ollama ${response.status}: ${(await response.text()).slice(0, 200)}`);
        error.status = response.status;
        throw error;
      }
      return await response.json();
    } finally {
      clearTimeout(timer);
    }
  }

  /** A chat without the model's reasoning: thinking models answer in a third of the time, and the
   * app's questions (tags, outfits) do not need it. An Ollama that does not know `think` is asked
   * again without it. */
  async answer(body, timeout) {
    if (this.thinking.has(body.model)) return this.call('/api/chat', body, timeout);
    try {
      return await this.call('/api/chat', { ...body, think: false }, timeout);
    } catch (error) {
      if (error.status !== 400 || !/think/i.test(error.message)) throw error;
      this.thinking.add(body.model);
      return this.call('/api/chat', body, timeout);
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
    const answer = await this.answer({
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
    const answer = await this.answer({
      model,
      stream: false,
      format: SCHEMA,
      keep_alive: '5m',
      options: { temperature: 0.2 },
      messages: [{ role: 'user', content: prompt(language), images: [image.toString('base64')] }],
      // Under the app's 180 s: a big model loading from the disk can take a couple of minutes.
    }, 170_000);
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
  // Some models write "unknown" or "N/A" instead of leaving a field empty.
  const read = (v, n) => (/^(unknown|n\/?a|none|-|—|sconosciut[oa]|non (visibile|leggibile))$/i.test(str(v, n)) ? '' : str(v, n));
  const colors = Array.isArray(raw.colors) ? [...new Set(raw.colors.map(colorKey))].filter(Boolean).slice(0, 3) : [];
  return {
    name: str(raw.name, 60),
    category: CATEGORIES.includes(raw.category) ? raw.category : 'other',
    colors,
    warmth: WARMTH[raw.warmth] ?? null,
    material: str(raw.material, 60),
    style: str(raw.style, 60),
    notes: str(raw.notes, 300),
    brand: read(raw.brand, 60),
    size: read(raw.size, 30),
  };
}
