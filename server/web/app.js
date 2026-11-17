// ShadowWear on the computer: the same closet as the iPhone app, from the server on the NAS.
// No libraries but a tiny QR maker (qr.mjs); the page is built with DOM calls only (never innerHTML with data).

import { generate as makeQR } from './qr.mjs';

const IT = (navigator.language || 'it').toLowerCase().startsWith('it');

// English for every Italian text on the page (Italian is the language of the code, as in the app).
const EN = {
  'Oggi': 'Today', 'Armadio': 'Closet', 'Outfit': 'Outfits', 'Diario': 'Diary', 'Impostazioni': 'Settings',
  'Esci': 'Sign out', 'Accedi': 'Sign in', 'Password': 'Password', 'Password sbagliata.': 'Wrong password.',
  'Benvenuto su ShadowWear': 'Welcome to ShadowWear',
  'Nome utente': 'User name', 'Nome utente o password sbagliati.': 'Wrong user name or password.',
  'Il nome utente deve avere da 1 a 40 caratteri, senza spazi.': 'The user name must have 1 to 40 characters, no spaces.',
  "Il primo accesso si crea dalla rete di casa: apri il server con l'indirizzo della NAS.": "The first sign-in is created from the home network: open the server with the NAS address.",
  'La password attuale è sbagliata.': 'The current password is wrong.', 'Il server ha già un account.': 'The server already has an account.',
  'Account': 'Account', 'Nuova password (facoltativa)': 'New password (optional)', 'Salva': 'Save',
  'Account aggiornato.': 'Account updated.',
  "Nell'app: Impostazioni → Server, scrivi questo indirizzo, il nome utente e la password.": 'In the app: Settings → Server, type this address, the user name and the password.',
  'Ripeti la password': 'Repeat the password', 'Le password non sono uguali.': 'The passwords do not match.',
  'Crea': 'Create', 'Il tuo armadio, dal server di casa.': 'Your closet, from your home server.',
  'Cerca nell\'armadio': 'Search the closet', 'Aggiungi capi': 'Add pieces', 'Tutti': 'All', 'Preferiti': 'Favorites',
  'capi': 'pieces', 'Il tuo armadio è vuoto': 'Your closet is empty',
  'Aggiungi le foto dei capi da qui, oppure dall\'app sull\'iPhone: si sincronizzano da sole.': 'Add photos of your pieces from here, or from the iPhone app: they sync on their own.',
  'Nessun capo corrisponde.': 'No piece matches.',
  'Maglie e camicie': 'Tops and shirts', 'Pantaloni e gonne': 'Trousers and skirts', 'Vestiti': 'Dresses',
  'Giacche e cappotti': 'Jackets and coats', 'Scarpe': 'Shoes', 'Borse': 'Bags', 'Accessori': 'Accessories', 'Altro': 'Other',
  'Maglia': 'Top', 'Pantaloni': 'Trousers', 'Vestito': 'Dress', 'Giacca': 'Jacket', 'Borsa': 'Bag', 'Accessorio': 'Accessory', 'Capo': 'Piece',
  'Nero': 'Black', 'Bianco': 'White', 'Grigio': 'Grey', 'Beige': 'Beige', 'Marrone': 'Brown', 'Rosso': 'Red', 'Bordeaux': 'Burgundy',
  'Rosa': 'Pink', 'Arancione': 'Orange', 'Giallo': 'Yellow', 'Verde oliva': 'Olive', 'Verde': 'Green', 'Azzurro': 'Light blue',
  'Blu': 'Blue', 'Blu scuro': 'Navy', 'Viola': 'Purple',
  'Tutti i giorni': 'Everyday', 'Lavoro': 'Work', 'Sport': 'Sport', 'Sera': 'Evening', 'Casa': 'Home',
  'Automatico': 'Automatic', 'Leggero': 'Light', 'Medio': 'Medium', 'Pesante': 'Warm',
  'Modifica capo': 'Edit piece', 'Nome': 'Name', 'Marca': 'Brand', 'Taglia': 'Size', 'Tipo': 'Kind', 'Peso': 'Weight',
  'Colori': 'Colors', 'Note': 'Notes', 'Preferito': 'Favorite', 'Salva': 'Save', 'Annulla': 'Cancel', 'Elimina': 'Delete',
  'Facoltativa': 'Optional', 'Il primo che scegli è il colore principale.': 'The first one you pick is the main color.',
  'Senza sfondo': 'Without background', 'Copertina': 'Cover', 'Usa come copertina': 'Use as cover', 'Togli la foto': 'Remove the photo',
  'Aggiungi foto': 'Add photos', 'Descrivi con l\'IA': 'Describe with AI', 'L\'IA sta guardando la foto…': 'The AI is looking at the photo…',
  'Fatto: controlla e salva.': 'Done: check and save.', 'Salvato.': 'Saved.', 'Eliminato.': 'Deleted.',
  'Eliminare questo capo? Le foto vanno via anche dall\'iPhone.': 'Delete this piece? Its photos leave the iPhone too.',
  'Carico le foto…': 'Uploading the photos…', 'capi aggiunti.': 'pieces added.',
  'Lo sfondo lo toglie l\'app sull\'iPhone (Togli lo sfondo, nel menu della foto).': 'The iPhone app removes the background (Remove background, in the photo menu).',
  'Messo': 'Worn', 'volte': 'times', 'L\'ultima volta': 'Last time', 'mai': 'never',
  'Nuovo outfit': 'New outfit', 'Modifica outfit': 'Edit outfit', 'Occasione': 'Occasion', 'Capi': 'Pieces',
  'Tocca i capi per aggiungerli.': 'Click the pieces to add them.', 'Nessun outfit': 'No outfits',
  'Metti insieme i capi dell\'armadio: li ritrovi qui e sull\'iPhone.': 'Put pieces of your closet together: you find them here and on the iPhone.',
  'L\'ho messo oggi': 'I wore it today', 'Annotato nel diario.': 'Written in the diary.',
  'Eliminare questo outfit? I capi restano.': 'Delete this outfit? The pieces stay.', 'Outfit senza nome': 'Untitled outfit',
  'Mese prima': 'Previous month', 'Mese dopo': 'Next month', 'Niente annotato per questo giorno.': 'Nothing written down for this day.',
  'Capi scelti': 'Chosen pieces', 'Aggiungi': 'Add', 'Scegli un outfit': 'Choose an outfit', 'Il mese': 'The month',
  'Giorni annotati': 'Days written down', 'I più messi': 'Worn the most', 'Capi mai messi': 'Never worn',
  'IA': 'AI', 'Modello': 'Model', 'Il server non ha Ollama: aggiungi OLLAMA_URL all\'app sulla NAS.': 'The server has no Ollama: add OLLAMA_URL to the app on the NAS.',
  'Scegli un modello che vede le immagini (segnato con 👁).': 'Choose a model that can see images (marked with 👁).',
  'Lingua delle descrizioni': 'Language of the descriptions', 'Italiano': 'Italian', 'Inglese': 'English',
  'Dispositivi collegati': 'Signed-in devices', 'questo browser': 'this browser', 'Scollega': 'Sign out',
  'Cambia password': 'Change password', 'Password attuale': 'Current password', 'Nuova password': 'New password',
  'Password cambiata: gli altri dispositivi devono riaccedere.': 'Password changed: the other devices must sign in again.',
  'Collegare l\'iPhone': 'Connect the iPhone',
  'Nell\'app: Impostazioni → Server, scrivi questo indirizzo e la password.': 'In the app: Settings → Server, type this address and the password.',
  'Versione del server': 'Server version', 'Ollama non risponde.': 'Ollama does not answer.', 'Carico i modelli…': 'Loading the models…',
  'Accedi prima.': 'Sign in first.', 'Errore': 'Error', 'Chiudi': 'Close', 'Cerca un capo': 'Search for a piece',
  'Idea per oggi': 'Idea for today',
  'Crea l\'accesso al server: nome utente e password li useranno il sito e l\'app sull\'iPhone per collegarsi. Password di almeno 10 caratteri: meglio qualche parola che nessuno indovina.': 'Create the server sign-in: the site and the iPhone app use the user name and password to connect. A password of at least 10 characters: a few words nobody would guess are best.',
  'La password deve avere almeno 10 caratteri.': 'The password must have at least 10 characters.',
  'Password troppo facile da indovinare: allungala o rendila meno prevedibile.': 'That password is too easy to guess: make it longer or less predictable.',
  'La password è troppo lunga.': 'The password is too long.',
  'Troppi tentativi sbagliati: aspetta qualche minuto e riprova.': 'Too many wrong tries: wait a few minutes and try again.',
  'Il server è occupato: riprova tra poco.': 'The server is busy: try again shortly.',
  'Richiesta non ammessa.': 'Request not allowed.',
  'Accedi con una passkey': 'Sign in with a passkey', 'oppure': 'or',
  'Accesso con la passkey annullato.': 'Passkey sign-in cancelled.',
  'Richiesta della passkey scaduta: riprova.': 'The passkey request expired: try again.',
  'Questa passkey non è più del server: accedi con la password.': 'This passkey is no longer on the server: sign in with the password.',
  'La passkey funziona solo dal sito del server in https.': 'The passkey only works from the server site over https.',
  'Le passkey funzionano solo aprendo il sito del server con il suo dominio in https.': 'Passkeys only work when you open the server site with its https domain.',
  'La passkey non ha verificato chi sei (Face ID, impronta o PIN).': 'The passkey did not check it is you (Face ID, fingerprint or PIN).',
  'La passkey è di un altro sito.': 'The passkey belongs to another site.', 'Firma della passkey non valida.': 'Invalid passkey signature.',
  'Questa passkey sembra copiata: eliminala e creane una nuova.': 'This passkey looks copied: delete it and make a new one.',
  "Questa passkey c'è già.": 'This passkey is already there.', 'Ci sono già 20 passkey: eliminane una.': 'There are already 20 passkeys: delete one.',
  'Tipo di passkey non supportato.': 'Passkey type not supported.', 'Passkey non trovata.': 'Passkey not found.',
  'Passkey': 'Passkeys', 'Aggiungi una passkey': 'Add a passkey', 'Nome della passkey': 'Name of the passkey',
  'Passkey aggiunta: la prossima volta entri senza password.': 'Passkey added: next time you sign in without a password.',
  'Passkey eliminata.': 'Passkey deleted.', 'Nessuna passkey.': 'No passkeys.', 'Usata': 'Used', 'Creata': 'Created',
  'Con una passkey entri sul sito con Face ID, l\'impronta o il PIN, senza password. Il server tiene solo la chiave pubblica: anche chi copiasse i suoi file non potrebbe entrare.': 'With a passkey you sign in to the site with Face ID, your fingerprint or PIN, no password. The server keeps only the public key: even someone who copied its files could not get in.',
  'Le passkey funzionano aprendo il sito con il suo dominio in https (per esempio quello che usi fuori casa), non con l\'indirizzo della NAS.': 'Passkeys work when you open the site with its https domain (the one you use away from home, for example), not with the NAS address.',
  'Collega un dispositivo': 'Connect a device', 'Crea un codice': 'Make a code', 'Annulla il codice': 'Cancel the code', 'Codice annullato.': 'Code cancelled.',
  'Per collegare l\'iPhone, l\'iPad o un altro browser senza scrivere la password: crea un codice e inquadra il QR con la fotocamera dell\'iPhone, oppure scrivi il codice nell\'app (Impostazioni → Server → Collega al server → Codice dal sito). Vale 10 minuti e una volta sola.': 'To connect the iPhone, the iPad or another browser without typing the password: make a code and scan the QR with the iPhone camera, or type the code in the app (Settings → Server → Connect to the server → Code from the site). It works for 10 minutes, once.',
  'Vale fino alle': 'Works until', 'Codice scaduto: creane un altro.': 'Code expired: make another one.',
  "Oppure, nell'app: Impostazioni → Server, con questo indirizzo, il nome utente e la password.": 'Or, in the app: Settings → Server, with this address, the user name and the password.',
  'con la password': 'with the password', 'con una passkey': 'with a passkey', 'con un codice': 'with a code',
  'Nuova password (facoltativa, almeno 10 caratteri)': 'New password (optional, at least 10 characters)',
  'Codice sbagliato o scaduto: creane uno nuovo dal sito.': 'Wrong or expired code: make a new one on the site.',
};

function t(text) {
  return IT ? text : (EN[text] ?? text);
}

const CATEGORIES = [
  ['top', 'Maglie e camicie', 'Maglia'], ['bottom', 'Pantaloni e gonne', 'Pantaloni'], ['dress', 'Vestiti', 'Vestito'],
  ['outerwear', 'Giacche e cappotti', 'Giacca'], ['shoes', 'Scarpe', 'Scarpe'], ['bag', 'Borse', 'Borsa'],
  ['accessory', 'Accessori', 'Accessorio'], ['other', 'Altro', 'Capo'],
];
const CATEGORY = Object.fromEntries(CATEGORIES.map(([k, label, name]) => [k, { label, name }]));
const COLORS = [
  ['black', 'Nero', 24, 24, 26], ['white', 'Bianco', 244, 244, 240], ['grey', 'Grigio', 140, 140, 146],
  ['beige', 'Beige', 214, 194, 158], ['brown', 'Marrone', 118, 78, 48], ['red', 'Rosso', 204, 38, 44],
  ['burgundy', 'Bordeaux', 112, 28, 44], ['pink', 'Rosa', 240, 152, 182], ['orange', 'Arancione', 240, 128, 40],
  ['yellow', 'Giallo', 242, 206, 58], ['olive', 'Verde oliva', 110, 114, 58], ['green', 'Verde', 56, 140, 72],
  ['lightblue', 'Azzurro', 138, 184, 226], ['blue', 'Blu', 44, 90, 172], ['navy', 'Blu scuro', 30, 40, 78],
  ['purple', 'Viola', 128, 70, 170],
];
const COLOR = Object.fromEntries(COLORS.map(([k, name, r, g, b]) => [k, { name, rgb: `rgb(${r},${g},${b})`, r, g, b }]));
const OCCASIONS = [['everyday', 'Tutti i giorni'], ['work', 'Lavoro'], ['sport', 'Sport'], ['evening', 'Sera'], ['home', 'Casa']];
const OCCASION = Object.fromEntries(OCCASIONS);
const WARMTH = [[null, 'Automatico'], [0, 'Leggero'], [1, 'Medio'], [2, 'Pesante']];

const state = {
  status: null, items: [], outfits: [], wears: [], photos: new Set(),
  tab: localStorage.getItem('sw-tab') || 'closet',
  category: null, query: '', favorites: false, occasion: null,
  month: monthStart(new Date()), day: dayKey(new Date()),
};

// ---------- helpers ----------

function h(tag, attrs = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs ?? {})) {
    if (v === undefined || v === null || v === false) continue;
    if (k === 'class') el.className = v;
    else if (k === 'style') el.style.cssText = v;
    else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
    else if (k === 'value') el.value = v;
    else if (k === 'checked') el.checked = v;
    else el.setAttribute(k, v === true ? '' : v);
  }
  for (const child of children.flat(Infinity)) {
    if (child === null || child === undefined || child === false) continue;
    el.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
  return el;
}

function uuid() {
  return crypto.randomUUID().toUpperCase();
}

/** Now as the app writes dates: no milliseconds. */
function isoNow() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
}

function dayKey(date) {
  const p = (n) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${p(date.getMonth() + 1)}-${p(date.getDate())}`;
}

function fromKey(key) {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function monthStart(date) {
  return new Date(date.getFullYear(), date.getMonth(), 1);
}

function fmt(date, options) {
  return date.toLocaleDateString(IT ? 'it-IT' : 'en-GB', options);
}

function toast(text, ms = 2600) {
  const el = document.getElementById('toast');
  el.textContent = text;
  el.classList.add('show');
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => el.classList.remove('show'), ms);
}

async function api(method, path, body, raw) {
  const res = await fetch(`/api/${path}`, {
    method,
    credentials: 'same-origin',
    headers: {
      'x-shadowwear': 'web',
      ...(body !== undefined ? { 'content-type': 'application/json' } : {}),
      ...(raw ? { 'content-type': raw.type || 'application/octet-stream' } : {}),
    },
    body: raw ?? (body !== undefined ? JSON.stringify(body) : undefined),
  });
  const data = (res.headers.get('content-type') ?? '').includes('json') ? await res.json() : null;
  if (res.status === 401 && data?.error === 'Accedi prima.') {
    state.status = { ...state.status, signedIn: false };
    render();
  }
  if (!res.ok) throw new Error(data?.error ? t(data.error) : `${t('Errore')} ${res.status}`);
  return data;
}

// ---------- passkeys ----------

const toB64 = (buffer) => btoa(String.fromCharCode(...new Uint8Array(buffer))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const fromB64 = (text) => Uint8Array.from(atob(text.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((text.length + 3) % 4)), (c) => c.charCodeAt(0));
const canPasskey = () => window.isSecureContext && 'PublicKeyCredential' in window;
const deviceName = () => `Browser ${navigator.platform || ''}`.trim();

/** NotAllowedError: the person closed the window of the passkey. */
function passkeyError(error) {
  return error?.name === 'NotAllowedError' || error?.name === 'AbortError' ? t('Accesso con la passkey annullato.') : error.message;
}

async function signInWithPasskey() {
  const options = await api('POST', 'passkey/options', {});
  const credential = await navigator.credentials.get({
    publicKey: { challenge: fromB64(options.challenge), rpId: options.rpId, timeout: options.timeout, userVerification: options.userVerification, allowCredentials: [] },
  });
  const r = credential.response;
  await api('POST', 'passkey/login', {
    id: credential.id,
    response: { clientDataJSON: toB64(r.clientDataJSON), authenticatorData: toB64(r.authenticatorData), signature: toB64(r.signature), userHandle: r.userHandle ? toB64(r.userHandle) : null },
    device: deviceName(),
  });
}

async function addPasskey(name) {
  const o = await api('POST', 'passkeys/options', {});
  const credential = await navigator.credentials.create({
    publicKey: {
      challenge: fromB64(o.challenge), rp: o.rp, user: { ...o.user, id: fromB64(o.user.id) },
      pubKeyCredParams: o.pubKeyCredParams, timeout: o.timeout, attestation: o.attestation,
      authenticatorSelection: o.authenticatorSelection,
      excludeCredentials: o.excludeCredentials.map((c) => ({ ...c, id: fromB64(c.id) })),
    },
  });
  return api('POST', 'passkeys', {
    response: { clientDataJSON: toB64(credential.response.clientDataJSON), attestationObject: toB64(credential.response.attestationObject) },
    name,
  });
}

function displayName(item) {
  return item.name?.trim() || t(CATEGORY[item.category]?.name ?? 'Capo');
}

function outfitName(outfit) {
  return outfit.name?.trim() || t('Outfit senza nome');
}

function usesCutout(photo) {
  return Boolean(photo.hasCutout) && photo.showCutout !== false;
}

function photoURL(photo, cutout = usesCutout(photo)) {
  return `/api/photos/${photo.id.toUpperCase()}.${cutout ? 'png' : 'jpg'}`;
}

function cover(item, cls = '') {
  const photo = item.photos?.[0];
  if (!photo) return h('span', { class: 'sub' }, t(CATEGORY[item.category]?.label ?? ''));
  return h('img', { src: photoURL(photo), alt: displayName(item), loading: 'lazy', class: usesCutout(photo) ? `cut ${cls}` : cls });
}

function itemByID(id) {
  return state.items.find((i) => i.id.toUpperCase() === String(id).toUpperCase());
}

function piecesOf(ids) {
  return (ids ?? []).map(itemByID).filter(Boolean);
}

function wornDays(id) {
  const k = id.toUpperCase();
  return [...new Set(state.wears.filter((w) => (w.items ?? []).some((i) => i.toUpperCase() === k)).map((w) => w.day))].sort().reverse();
}

function collage(pieces) {
  const order = ['top', 'dress', 'bottom', 'outerwear', 'accessory', 'bag', 'shoes', 'other'];
  const sorted = [...pieces].sort((a, b) => order.indexOf(a.category) - order.indexOf(b.category));
  const main = sorted.filter((p) => ['top', 'dress', 'bottom'].includes(p.category));
  const side = sorted.filter((p) => !['top', 'dress', 'bottom'].includes(p.category));
  const col = (list) => h('div', { class: 'col' }, list.map((p) => cover(p)));
  if (!main.length || !side.length) return h('div', { class: 'collage one' }, col(main.length ? main : side));
  return h('div', { class: 'collage' }, col(main), col(side));
}

// ---------- start ----------

async function boot() {
  try {
    state.status = await api('GET', 'status');
  } catch (error) {
    return renderMessage(error.message);
  }
  if (state.status.signedIn) await load();
  render();
}

async function load() {
  const data = await api('GET', 'closet');
  state.items = data.items;
  state.outfits = data.outfits;
  state.wears = data.wears;
  state.photos = new Set(data.photos);
}

function renderMessage(text) {
  document.getElementById('app').replaceChildren(h('p', { class: 'loading' }, text));
}

function render() {
  const app = document.getElementById('app');
  if (!state.status.configured) return app.replaceChildren(setupView());
  if (!state.status.signedIn) return app.replaceChildren(loginView());
  const tabs = [['closet', 'Armadio', '👕'], ['outfits', 'Outfit', '🧥'], ['diary', 'Diario', '📅'], ['settings', 'Impostazioni', '⚙︎']];
  const views = { closet: closetView, outfits: outfitsView, diary: diaryView, settings: settingsView };
  app.replaceChildren(
    h('div', { class: 'shell' },
      h('nav', { class: 'nav' },
        h('div', { class: 'brand' }, h('img', { src: 'icon.png', alt: '' }), 'ShadowWear'),
        tabs.map(([key, label, icon]) => h('button', {
          class: state.tab === key ? 'on' : '',
          onclick: () => { state.tab = key; localStorage.setItem('sw-tab', key); render(); },
        }, h('span', { 'aria-hidden': 'true' }, icon), t(label))),
        h('div', { class: 'spacer' }),
        h('div', { class: 'who' }, `${state.items.length} ${t('capi')}`)),
      h('main', {}, (views[state.tab] ?? closetView)())));
}

function setupView() {
  const user = h('input', { type: 'text', placeholder: t('Nome utente'), autocomplete: 'username', autocapitalize: 'none', spellcheck: 'false', autofocus: true });
  const one = h('input', { type: 'password', placeholder: t('Password'), autocomplete: 'new-password' });
  const two = h('input', { type: 'password', placeholder: t('Ripeti la password'), autocomplete: 'new-password' });
  const error = h('div', { class: 'error' });
  const go = async (event) => {
    event.preventDefault();
    if (one.value !== two.value) return (error.textContent = t('Le password non sono uguali.'));
    try {
      await api('POST', 'setup', { user: user.value, password: one.value, device: deviceName() });
      state.status = await api('GET', 'status');
      await load();
      render();
    } catch (e) {
      error.textContent = e.message;
    }
  };
  return h('form', { class: 'login', onsubmit: go },
    h('img', { src: 'icon.png', alt: '' }),
    h('h1', {}, t('Benvenuto su ShadowWear')),
    h('p', { class: 'sub' }, t('Crea l\'accesso al server: nome utente e password li useranno il sito e l\'app sull\'iPhone per collegarsi. Password di almeno 10 caratteri: meglio qualche parola che nessuno indovina.')),
    user, one, two, error,
    h('button', { class: 'btn primary', type: 'submit' }, t('Crea')));
}

function loginView() {
  const user = h('input', { type: 'text', placeholder: t('Nome utente'), autocomplete: 'username', autocapitalize: 'none', spellcheck: 'false', autofocus: true });
  const password = h('input', { type: 'password', placeholder: t('Password'), autocomplete: 'current-password' });
  const error = h('div', { class: 'error' });
  const go = async (event) => {
    event.preventDefault();
    try {
      await api('POST', 'login', { user: user.value, password: password.value, device: deviceName() });
      state.status = await api('GET', 'status');
      await load();
      render();
    } catch (e) {
      error.textContent = e.message;
    }
  };
  const passkey = async () => {
    try {
      await signInWithPasskey();
      state.status = await api('GET', 'status');
      await load();
      render();
    } catch (e) {
      error.textContent = passkeyError(e);
    }
  };
  const withPasskey = canPasskey() && state.status.passkeys;
  return h('form', { class: 'login', onsubmit: go },
    h('img', { src: 'icon.png', alt: '' }),
    h('h1', {}, 'ShadowWear'),
    h('p', { class: 'sub' }, t('Il tuo armadio, dal server di casa.')),
    withPasskey ? [h('button', { class: 'btn primary', type: 'button', onclick: passkey }, '🔑 ', t('Accedi con una passkey')),
      h('p', { class: 'sub small' }, t('oppure'))] : null,
    user, password, error,
    h('button', { class: withPasskey ? 'btn' : 'btn primary', type: 'submit' }, t('Accedi')));
}

// ---------- closet ----------

function closetView() {
  const shown = state.items
    .filter((i) => !state.category || i.category === state.category)
    .filter((i) => !state.favorites || i.favorite)
    .filter((i) => matches(i, state.query))
    .sort((a, b) => (b.created ?? '').localeCompare(a.created ?? ''));
  const counts = {};
  for (const i of state.items) counts[i.category] = (counts[i.category] ?? 0) + 1;

  const search = h('input', { type: 'search', class: 'grow', placeholder: t('Cerca nell\'armadio'), value: state.query });
  search.addEventListener('input', () => {
    state.query = search.value;
    const grid = document.getElementById('closet-grid');
    grid?.replaceWith(closetGrid(closetFiltered()));
  });
  const file = h('input', { type: 'file', accept: 'image/*', multiple: true, hidden: true, onchange: () => addPhotos([...file.files]) });

  return h('div', {},
    h('h1', {}, t('Armadio')),
    h('div', { class: 'sub small' }, `${state.items.length} ${t('capi')}`),
    h('div', { class: 'bar' }, search, file,
      h('button', { class: 'btn primary', onclick: () => file.click() }, '+ ', t('Aggiungi capi'))),
    state.items.length ? h('div', { class: 'chips' },
      h('button', { class: `chip ${!state.category ? 'on' : ''}`, onclick: () => { state.category = null; render(); } }, t('Tutti'), h('span', { class: 'n' }, state.items.length)),
      CATEGORIES.filter(([k]) => counts[k]).map(([k, label]) => h('button', {
        class: `chip ${state.category === k ? 'on' : ''}`,
        onclick: () => { state.category = state.category === k ? null : k; render(); },
      }, t(label), h('span', { class: 'n' }, counts[k]))),
      h('button', { class: `chip ${state.favorites ? 'on' : ''}`, onclick: () => { state.favorites = !state.favorites; render(); } }, '★ ', t('Preferiti'))) : null,
    h('div', { style: 'height:12px' }),
    state.items.length ? closetGrid(shown)
      : h('div', { class: 'empty' }, h('div', { class: 'big' }, '👕'), h('h2', {}, t('Il tuo armadio è vuoto')),
        h('p', {}, t('Aggiungi le foto dei capi da qui, oppure dall\'app sull\'iPhone: si sincronizzano da sole.'))));
}

function closetFiltered() {
  return state.items
    .filter((i) => !state.category || i.category === state.category)
    .filter((i) => !state.favorites || i.favorite)
    .filter((i) => matches(i, state.query))
    .sort((a, b) => (b.created ?? '').localeCompare(a.created ?? ''));
}

function matches(item, query) {
  const q = query.trim().toLowerCase();
  if (!q) return true;
  const fields = [item.name, item.brand, item.size, item.notes, t(CATEGORY[item.category]?.label ?? ''),
    ...(item.colors ?? []).map((c) => t(COLOR[c]?.name ?? c))];
  const plain = (s) => String(s ?? '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
  return fields.some((f) => plain(f).includes(plain(q)));
}

function closetGrid(items) {
  if (!items.length) return h('p', { id: 'closet-grid', class: 'empty' }, t('Nessun capo corrisponde.'));
  return h('div', { id: 'closet-grid', class: 'grid' }, items.map((item) => h('button', { class: 'card', onclick: () => openItem(item.id) },
    h('div', { class: 'pic' }, cover(item)),
    item.favorite ? h('span', { class: 'star' }, '★') : null,
    h('div', { class: 'meta' },
      h('div', { class: 'name' }, displayName(item)),
      h('div', { class: 'line' },
        (item.colors ?? []).slice(0, 3).map((c) => COLOR[c] ? h('span', { class: 'dot', style: `background:${COLOR[c].rgb}` }) : null),
        item.brand || t(CATEGORY[item.category]?.label ?? ''))))));
}

/** Photos from the computer: each becomes a piece (as on the iPhone), the colors guessed here. */
async function addPhotos(files) {
  if (!files.length) return;
  toast(t('Carico le foto…'), 60_000);
  let last = null;
  let done = 0;
  for (const file of files) {
    try {
      const { blob, colors } = await prepare(file);
      const photo = { id: uuid(), hasCutout: false, showCutout: true };
      await api('PUT', `photos/${photo.id}.jpg`, undefined, blob);
      const now = isoNow();
      const item = { id: uuid(), name: '', category: 'other', colors, brand: '', size: '', notes: '', favorite: false, photos: [photo], created: now, updated: now };
      await api('PUT', `items/${item.id}`, item);
      last = item.id;
      done += 1;
    } catch (error) {
      toast(error.message, 5000);
    }
  }
  await load();
  render();
  toast(`${done} ${t('capi aggiunti.')} ${t('Lo sfondo lo toglie l\'app sull\'iPhone (Togli lo sfondo, nel menu della foto).')}`, 6000);
  if (last) openItem(last, { describe: Boolean(state.status.ai?.available && state.status.ai?.model) });
}

/** The photo as a JPEG of at most 1600 px, and its main colors (from the middle of the picture). */
async function prepare(file) {
  const bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' });
  const scale = Math.min(1, 1600 / Math.max(bitmap.width, bitmap.height));
  const canvas = document.createElement('canvas');
  canvas.width = Math.round(bitmap.width * scale);
  canvas.height = Math.round(bitmap.height * scale);
  const ctx = canvas.getContext('2d');
  ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  const blob = await new Promise((resolve) => canvas.toBlob(resolve, 'image/jpeg', 0.88));

  const small = document.createElement('canvas');
  small.width = 40;
  small.height = 40;
  const sctx = small.getContext('2d', { willReadFrequently: true });
  sctx.drawImage(bitmap, bitmap.width * 0.25, bitmap.height * 0.2, bitmap.width * 0.5, bitmap.height * 0.6, 0, 0, 40, 40);
  const { data } = sctx.getImageData(0, 0, 40, 40);
  const counts = {};
  for (let i = 0; i < data.length; i += 4) {
    let best = null;
    let dist = Infinity;
    for (const [k, , r, g, b] of COLORS) {
      const d = (data[i] - r) ** 2 * 0.3 + (data[i + 1] - g) ** 2 * 0.59 + (data[i + 2] - b) ** 2 * 0.11;
      if (d < dist) { dist = d; best = k; }
    }
    counts[best] = (counts[best] ?? 0) + 1;
  }
  const total = 1600;
  const colors = Object.entries(counts).sort((a, b) => b[1] - a[1]).filter(([, n], i) => i === 0 || n / total > 0.18).slice(0, 2).map(([k]) => k);
  return { blob, colors };
}

function dialog(title, body, actions) {
  const dlg = document.getElementById('dialog');
  dlg.replaceChildren(
    h('div', { class: 'dlg-head' }, h('h3', {}, title), ...actions),
    h('div', { class: 'dlg-body' }, body));
  if (!dlg.open) dlg.showModal();
  return dlg;
}

function closeDialog() {
  document.getElementById('dialog').close();
}

function openItem(id, { describe = false } = {}) {
  const original = itemByID(id);
  if (!original) return;
  const item = structuredClone(original);
  item.photos ??= [];
  item.colors ??= [];
  const body = h('div', { class: 'dlg-body', style: 'padding:0' });
  const busy = h('span', {});

  const draw = () => {
    const days = wornDays(item.id);
    body.replaceChildren(
      h('div', { class: 'photos' }, item.photos.map((photo, index) => h('figure', {},
        h('div', { class: 'pic' }, h('img', { src: photoURL(photo), alt: '' })),
        photo.hasCutout ? h('label', { class: 'row' }, h('input', {
          type: 'checkbox', checked: photo.showCutout !== false,
          onchange: (e) => { photo.showCutout = e.target.checked; draw(); },
        }), t('Senza sfondo')) : null,
        index === 0 ? h('span', {}, t('Copertina')) : h('button', { class: 'btn small', onclick: () => { item.photos.unshift(...item.photos.splice(index, 1)); draw(); } }, t('Usa come copertina')),
        item.photos.length > 1 ? h('button', { class: 'btn small danger', onclick: () => { item.photos.splice(index, 1); draw(); } }, t('Togli la foto')) : null))),
      h('div', { class: 'two' },
        field(t('Nome'), input(item, 'name', t(CATEGORY[item.category]?.name ?? 'Capo'))),
        field(t('Marca'), input(item, 'brand', t('Facoltativa')))),
      h('div', { class: 'two' },
        field(t('Taglia'), input(item, 'size', t('Facoltativa'))),
        field(t('Peso'), h('div', { class: 'segmented' }, WARMTH.map(([value, label]) => h('button', {
          type: 'button', class: (item.warmth ?? null) === value ? 'on' : '',
          onclick: () => { if (value === null) delete item.warmth; else item.warmth = value; draw(); },
        }, t(label)))))),
      field(t('Tipo'), h('div', { class: 'kinds' }, CATEGORIES.map(([k, label]) => h('button', {
        type: 'button', class: `kind ${item.category === k ? 'on' : ''}`, onclick: () => { item.category = k; draw(); },
      }, t(label))))),
      field(t('Colori'), h('div', { class: 'swatches' }, COLORS.map(([k, name]) => {
        const i = item.colors.indexOf(k);
        return h('button', {
          type: 'button', class: `swatch ${i >= 0 ? 'on' : ''}`,
          onclick: () => { if (i >= 0) item.colors.splice(i, 1); else item.colors.push(k); draw(); },
        }, h('span', { class: 'c', style: `background:${COLOR[k].rgb};color:${['white', 'beige', 'yellow', 'lightblue', 'pink'].includes(k) ? '#111' : '#fff'}` }, i >= 0 ? i + 1 : ''), t(name));
      })), h('span', { class: 'sub small' }, t('Il primo che scegli è il colore principale.'))),
      field(t('Note'), (() => { const a = h('textarea', {}); a.value = item.notes ?? ''; a.oninput = () => { item.notes = a.value; }; return a; })()),
      h('label', { class: 'row' }, h('input', { type: 'checkbox', checked: Boolean(item.favorite), onchange: (e) => { item.favorite = e.target.checked; } }), '★ ', t('Preferito')),
      h('div', { class: 'info' }, h('span', {}, t('Messo')), h('span', {}, `${days.length} ${t('volte')}`)),
      h('div', { class: 'info' }, h('span', {}, t('L\'ultima volta')), h('span', {}, days[0] ? fmt(fromKey(days[0]), { day: 'numeric', month: 'long', year: 'numeric' }) : t('mai'))),
      h('div', { class: 'bar' },
        state.status.ai?.available ? h('button', { class: 'btn', onclick: () => describeItem(item, busy, draw) }, '✦ ', t('Descrivi con l\'IA')) : null,
        busy,
        h('div', { class: 'grow' }),
        h('button', { class: 'btn danger', onclick: () => deleteItem(item.id) }, t('Elimina'))));
  };
  draw();
  dialog(t('Modifica capo'), body, [
    h('button', { class: 'btn', onclick: closeDialog }, t('Annulla')),
    h('button', { class: 'btn primary', onclick: () => saveItem(item) }, t('Salva')),
  ]);
  if (describe) describeItem(item, busy, draw);
}

function field(label, control, ...rest) {
  return h('label', { class: 'field' }, label, control, ...rest);
}

function input(object, key, placeholder) {
  const el = h('input', { type: 'text', placeholder, value: object[key] ?? '' });
  el.addEventListener('input', () => { object[key] = el.value; });
  return el;
}

async function describeItem(item, busy, draw) {
  const photo = item.photos[0];
  if (!photo) return;
  busy.replaceChildren(h('span', { class: 'spin' }), ' ', t('L\'IA sta guardando la foto…'));
  try {
    const image = await (await fetch(photoURL(photo), { credentials: 'same-origin' })).blob();
    const answer = await api('POST', `ai/describe?lang=${IT ? 'it' : 'en'}`, undefined, image);
    if (answer.name) item.name = answer.name;
    item.category = answer.category ?? item.category;
    if (answer.colors?.length) item.colors = answer.colors;
    if (answer.warmth !== null && answer.warmth !== undefined) item.warmth = answer.warmth;
    const extra = [answer.material, answer.style].filter(Boolean).join(', ');
    const notes = [extra, answer.notes].filter(Boolean).join('. ');
    if (notes && !item.notes) item.notes = notes;
    draw();
    busy.replaceChildren(t('Fatto: controlla e salva.'));
  } catch (error) {
    busy.replaceChildren(h('span', { class: 'error' }, error.message));
  }
}

async function saveItem(item) {
  try {
    await api('PUT', `items/${item.id}`, item);
    await load();
    closeDialog();
    render();
    toast(t('Salvato.'));
  } catch (error) {
    toast(error.message, 5000);
  }
}

async function deleteItem(id) {
  if (!confirm(t('Eliminare questo capo? Le foto vanno via anche dall\'iPhone.'))) return;
  await api('DELETE', `items/${id}`);
  await load();
  closeDialog();
  render();
  toast(t('Eliminato.'));
}

// ---------- outfits ----------

function outfitsView() {
  const shown = state.outfits
    .filter((o) => !state.occasion || o.occasion === state.occasion)
    .sort((a, b) => (b.created ?? '').localeCompare(a.created ?? ''));
  return h('div', {},
    h('h1', {}, t('Outfit')),
    h('div', { class: 'bar' },
      h('div', { class: 'chips grow' },
        h('button', { class: `chip ${!state.occasion ? 'on' : ''}`, onclick: () => { state.occasion = null; render(); } }, t('Tutti'), h('span', { class: 'n' }, state.outfits.length)),
        OCCASIONS.filter(([k]) => state.outfits.some((o) => o.occasion === k)).map(([k, label]) => h('button', {
          class: `chip ${state.occasion === k ? 'on' : ''}`, onclick: () => { state.occasion = state.occasion === k ? null : k; render(); },
        }, t(label)))),
      h('button', { class: 'btn primary', disabled: !state.items.length, onclick: () => openOutfit(null) }, '+ ', t('Nuovo outfit'))),
    shown.length ? h('div', { class: 'grid' }, shown.map((outfit) => h('button', { class: 'card', onclick: () => openOutfit(outfit.id) },
      collage(piecesOf(outfit.items)),
      outfit.favorite ? h('span', { class: 'star' }, '★') : null,
      h('div', { class: 'meta' },
        h('div', { class: 'name' }, outfitName(outfit)),
        h('div', { class: 'line' }, outfit.occasion ? t(OCCASION[outfit.occasion]) : `${piecesOf(outfit.items).length} ${t('capi')}`)))))
      : h('div', { class: 'empty' }, h('div', { class: 'big' }, '🧥'), h('h2', {}, t('Nessun outfit')), h('p', {}, t('Metti insieme i capi dell\'armadio: li ritrovi qui e sull\'iPhone.'))));
}

function openOutfit(id) {
  const existing = id ? state.outfits.find((o) => o.id === id) : null;
  const now = isoNow();
  const outfit = existing ? structuredClone(existing) : { id: uuid(), name: '', items: [], favorite: false, notes: '', created: now, updated: now };
  let category = null;
  let query = '';
  const body = h('div', { class: 'dlg-body', style: 'padding:0' });
  const draw = () => {
    const picked = new Set(outfit.items.map((i) => i.toUpperCase()));
    const choices = state.items.filter((i) => (!category || i.category === category) && matches(i, query));
    const search = h('input', { type: 'search', placeholder: t('Cerca un capo'), value: query });
    search.addEventListener('change', () => { query = search.value; draw(); });
    body.replaceChildren(
      h('div', { style: 'max-width:280px' }, collage(piecesOf(outfit.items))),
      outfit.items.length ? null : h('p', { class: 'sub' }, t('Tocca i capi per aggiungerli.')),
      field(t('Nome'), input(outfit, 'name', 'Ufficio, Weekend…')),
      field(t('Occasione'), h('div', { class: 'chips' }, OCCASIONS.map(([k, label]) => h('button', {
        type: 'button', class: `chip ${outfit.occasion === k ? 'on' : ''}`,
        onclick: () => { if (outfit.occasion === k) delete outfit.occasion; else outfit.occasion = k; draw(); },
      }, t(label))))),
      h('label', { class: 'row' }, h('input', { type: 'checkbox', checked: Boolean(outfit.favorite), onchange: (e) => { outfit.favorite = e.target.checked; } }), '★ ', t('Preferito')),
      field(`${t('Capi')} (${outfit.items.length})`,
        h('div', { class: 'chips' },
          h('button', { type: 'button', class: `chip ${!category ? 'on' : ''}`, onclick: () => { category = null; draw(); } }, t('Tutti')),
          CATEGORIES.filter(([k]) => state.items.some((i) => i.category === k)).map(([k, label]) => h('button', {
            type: 'button', class: `chip ${category === k ? 'on' : ''}`, onclick: () => { category = category === k ? null : k; draw(); },
          }, t(label)))),
        search),
      h('div', { class: 'grid', style: 'grid-template-columns:repeat(auto-fill,minmax(110px,1fr))' }, choices.map((item) => h('button', {
        type: 'button', class: `card pick ${picked.has(item.id.toUpperCase()) ? 'on' : ''}`,
        onclick: () => {
          const i = outfit.items.findIndex((x) => x.toUpperCase() === item.id.toUpperCase());
          if (i >= 0) outfit.items.splice(i, 1); else outfit.items.push(item.id);
          draw();
        },
      }, h('div', { class: 'pic' }, cover(item)), h('div', { class: 'meta' }, h('div', { class: 'name small' }, displayName(item)))))),
      field(t('Note'), (() => { const a = h('textarea', {}); a.value = outfit.notes ?? ''; a.oninput = () => { outfit.notes = a.value; }; return a; })()),
      existing ? h('div', { class: 'bar' },
        h('button', { class: 'btn', onclick: () => wear(outfit.items, outfit.id) }, '✓ ', t('L\'ho messo oggi')),
        h('div', { class: 'grow' }),
        h('button', { class: 'btn danger', onclick: () => deleteOutfit(outfit.id) }, t('Elimina'))) : null);
  };
  draw();
  dialog(existing ? t('Modifica outfit') : t('Nuovo outfit'), body, [
    h('button', { class: 'btn', onclick: closeDialog }, t('Annulla')),
    h('button', { class: 'btn primary', onclick: () => saveOutfit(outfit) }, t('Salva')),
  ]);
}

async function saveOutfit(outfit) {
  if (!outfit.items.length) return;
  if (!outfit.name.trim()) {
    outfit.name = piecesOf(outfit.items).filter((p) => ['top', 'dress', 'bottom'].includes(p.category)).slice(0, 2).map(displayName).join(' + ');
  }
  try {
    await api('PUT', `outfits/${outfit.id}`, outfit);
    await load();
    closeDialog();
    render();
    toast(t('Salvato.'));
  } catch (error) {
    toast(error.message, 5000);
  }
}

async function deleteOutfit(id) {
  if (!confirm(t('Eliminare questo outfit? I capi restano.'))) return;
  await api('DELETE', `outfits/${id}`);
  await load();
  closeDialog();
  render();
}

async function wear(items, outfit, day = dayKey(new Date())) {
  const entry = { id: uuid(), day, items: [...items] };
  if (outfit) entry.outfit = outfit;
  await api('PUT', `wears/${entry.id}`, entry);
  await load();
  render();
  toast(t('Annotato nel diario.'));
}

// ---------- diary ----------

function diaryView() {
  const month = state.month;
  const first = new Date(month);
  const lead = (first.getDay() + 6) % 7; // Monday first
  const days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
  const today = dayKey(new Date());
  const weekdays = Array.from({ length: 7 }, (_, i) => fmt(new Date(2024, 0, 1 + i), { weekday: 'narrow' }));
  const cells = [];
  for (let i = 0; i < lead; i += 1) cells.push(h('div', {}));
  for (let d = 1; d <= days; d += 1) {
    const key = dayKey(new Date(month.getFullYear(), month.getMonth(), d));
    const entry = state.wears.find((w) => w.day === key);
    const piece = entry ? piecesOf(entry.items)[0] : null;
    cells.push(h('button', {
      class: `day ${piece ? 'worn' : ''} ${key === today ? 'today' : ''} ${key === state.day ? 'sel' : ''}`,
      onclick: () => { state.day = key; render(); },
      'aria-label': fmt(fromKey(key), { weekday: 'long', day: 'numeric', month: 'long' }),
    }, h('span', { class: 'n' }, d), piece?.photos?.[0] ? h('img', { src: photoURL(piece.photos[0]), alt: '' }) : null));
  }
  const move = (n) => { state.month = new Date(month.getFullYear(), month.getMonth() + n, 1); render(); };

  const entries = state.wears.filter((w) => w.day === state.day);
  const select = h('select', {}, h('option', { value: '' }, t('Scegli un outfit')),
    state.outfits.map((o) => h('option', { value: o.id }, outfitName(o))));

  const prefix = dayKey(month).slice(0, 7);
  const monthWears = state.wears.filter((w) => w.day.startsWith(prefix));
  const counts = {};
  for (const w of monthWears) for (const id of new Set((w.items ?? []).map((i) => i.toUpperCase()))) counts[id] = (counts[id] ?? 0) + 1;
  const top = Object.entries(counts).sort((a, b) => b[1] - a[1]).slice(0, 3).map(([id, n]) => [itemByID(id), n]).filter(([i]) => i);
  const ever = new Set(state.wears.flatMap((w) => (w.items ?? []).map((i) => i.toUpperCase())));
  const never = state.items.filter((i) => !ever.has(i.id.toUpperCase()));

  return h('div', {},
    h('h1', {}, t('Diario')),
    h('div', { class: 'bar' },
      h('button', { class: 'btn small', onclick: () => move(-1), 'aria-label': t('Mese prima') }, '‹'),
      h('strong', { style: 'min-width:180px;text-align:center' }, fmt(month, { month: 'long', year: 'numeric' })),
      h('button', { class: 'btn small', onclick: () => move(1), 'aria-label': t('Mese dopo') }, '›')),
    h('div', { style: 'display:grid;grid-template-columns:minmax(0,560px) minmax(0,1fr);gap:20px;align-items:start', class: 'diary' },
      h('div', { class: 'month' }, weekdays.map((w) => h('div', { class: 'wd' }, w)), cells),
      h('div', { style: 'display:flex;flex-direction:column;gap:14px' },
        h('div', { class: 'panel' },
          h('strong', {}, fmt(fromKey(state.day), { weekday: 'long', day: 'numeric', month: 'long' })),
          entries.length ? entries.map((w) => {
            const pieces = piecesOf(w.items);
            const outfit = w.outfit ? state.outfits.find((o) => o.id.toUpperCase() === w.outfit.toUpperCase()) : null;
            return h('div', { class: 'row' },
              h('div', { class: 'thumb' }, collage(pieces)),
              h('div', { class: 'grow' }, h('strong', {}, outfit ? outfitName(outfit) : t('Capi scelti')),
                h('div', { class: 'sub small' }, pieces.map(displayName).join(', '))),
              h('button', { class: 'btn small danger', onclick: async () => { await api('DELETE', `wears/${w.id}`); await load(); render(); } }, '✕'));
          }) : h('span', { class: 'sub' }, t('Niente annotato per questo giorno.')),
          state.outfits.length && state.day <= dayKey(new Date()) ? h('div', { class: 'bar' }, select,
            h('button', { class: 'btn', onclick: () => {
              const o = state.outfits.find((x) => x.id === select.value);
              if (o) wear(o.items, o.id, state.day);
            } }, t('Aggiungi'))) : null),
        h('div', { class: 'panel' },
          h('strong', {}, t('Il mese')),
          h('div', { class: 'info' }, h('span', {}, t('Giorni annotati')), h('span', {}, new Set(monthWears.map((w) => w.day)).size)),
          top.length ? h('span', { class: 'sub small' }, t('I più messi')) : null,
          top.map(([item, n]) => h('div', { class: 'info' }, h('span', {}, displayName(item)), h('span', {}, `${n}×`))),
          h('div', { class: 'info' }, h('span', {}, t('Capi mai messi')), h('span', {}, `${never.length} / ${state.items.length}`))))));
}

// ---------- settings ----------

function settingsView() {
  const box = h('div', { style: 'display:flex;flex-direction:column;gap:6px;max-width:720px' });
  const ai = h('div', { class: 'panel' }, h('strong', {}, t('IA')));
  const devices = h('div', { class: 'panel' }, h('strong', {}, t('Dispositivi collegati')));
  const VIA = { password: 'con la password', passkey: 'con una passkey', codice: 'con un codice' };

  if (!state.status.ai?.available) {
    ai.append(h('span', { class: 'sub' }, t('Il server non ha Ollama: aggiungi OLLAMA_URL all\'app sulla NAS.')));
  } else {
    const holder = h('div', {}, h('span', { class: 'sub' }, t('Carico i modelli…')));
    ai.append(holder);
    Promise.all([api('GET', 'ai/models'), api('GET', 'settings')]).then(([models, settings]) => {
      const select = h('select', {}, h('option', { value: '' }, '—'),
        models.models.map((m) => h('option', { value: m.name, selected: m.name === settings.aiModel }, `${m.vision ? '👁 ' : ''}${m.name}`)));
      const lang = h('select', {},
        h('option', { value: 'it', selected: settings.language === 'it' }, t('Italiano')),
        h('option', { value: 'en', selected: settings.language === 'en' }, t('Inglese')));
      const save = async () => {
        const saved = await api('PUT', 'settings', { aiModel: select.value, language: lang.value });
        state.status.ai.model = saved.aiModel;
        toast(t('Salvato.'));
      };
      select.onchange = save;
      lang.onchange = save;
      holder.replaceChildren(
        field(t('Modello'), select, h('span', { class: 'sub small' }, t('Scegli un modello che vede le immagini (segnato con 👁).'))),
        field(t('Lingua delle descrizioni'), lang));
    }).catch(() => holder.replaceChildren(h('span', { class: 'error' }, t('Ollama non risponde.'))));
  }

  api('GET', 'devices').then(({ devices: list }) => {
    for (const d of list) {
      devices.append(h('div', { class: 'row' },
        h('div', { class: 'grow' }, h('div', {}, d.name, d.current ? h('span', { class: 'sub' }, ` (${t('questo browser')})`) : null),
          h('div', { class: 'sub small' }, fmt(new Date(d.seen), { day: 'numeric', month: 'short', year: 'numeric' }), ' · ', t(VIA[d.via] ?? VIA.password))),
        h('button', { class: 'btn small danger', onclick: async () => {
          await api('DELETE', `devices/${d.id}`);
          if (d.current) location.reload(); else render();
        } }, t('Scollega'))));
    }
  });

  const userName = h('input', { type: 'text', placeholder: t('Nome utente'), autocomplete: 'username', autocapitalize: 'none', spellcheck: 'false' });
  api('GET', 'account').then((a) => { userName.value = a.user ?? ''; }).catch(() => {});
  const current = h('input', { type: 'password', placeholder: t('Password attuale'), autocomplete: 'current-password' });
  const next = h('input', { type: 'password', placeholder: t('Nuova password (facoltativa, almeno 10 caratteri)'), autocomplete: 'new-password' });
  const passError = h('div', { class: 'error' });

  box.append(
    h('h1', {}, t('Impostazioni')),
    h('h2', {}, t('Collega un dispositivo')), linkPanel(),
    h('h2', {}, t('IA')), ai,
    h('h2', {}, t('Dispositivi collegati')), devices,
    h('h2', {}, t('Passkey')), passkeysPanel(),
    h('h2', {}, t('Account')),
    h('form', { class: 'panel', onsubmit: async (e) => {
      e.preventDefault();
      try {
        const changed = Boolean(next.value);
        await api('POST', 'account', { current: current.value, user: userName.value, next: next.value });
        current.value = '';
        next.value = '';
        passError.textContent = '';
        toast(t(changed ? 'Password cambiata: gli altri dispositivi devono riaccedere.' : 'Account aggiornato.'), 5000);
        render();
      } catch (error) {
        passError.textContent = error.message;
      }
    } }, userName, current, next, passError, h('button', { class: 'btn', type: 'submit' }, t('Salva'))),
    h('div', { class: 'bar' },
      h('span', { class: 'sub small grow' }, `${t('Versione del server')}: ${state.status.version}`),
      h('button', { class: 'btn danger', onclick: async () => { await api('POST', 'logout'); location.reload(); } }, t('Esci'))));
  return box;
}

/** A code (and its QR) for a new device: works ten minutes, once. */
function linkPanel() {
  const shown = h('div', { class: 'link-code' });
  const make = h('button', { class: 'btn primary', type: 'button' }, t('Crea un codice'));
  let timer = null;
  const clear = () => {
    clearInterval(timer);
    shown.replaceChildren();
    make.hidden = false;
  };
  make.onclick = async () => {
    try {
      const { code, expires } = await api('POST', 'link');
      const until = new Date(expires);
      const canvas = h('canvas', { class: 'qr', 'aria-label': code });
      makeQR(`shadowwear://link?server=${encodeURIComponent(location.origin)}&code=${code}`).toCanvas(canvas, { on: [15, 15, 17], off: [255, 255, 255, 255], pad: 3 });
      shown.replaceChildren(canvas,
        h('div', { class: 'code' }, code),
        h('div', { class: 'sub small' }, `${t('Vale fino alle')} ${until.toLocaleTimeString(IT ? 'it-IT' : 'en-GB', { hour: '2-digit', minute: '2-digit' })}`),
        h('button', { class: 'btn small', type: 'button', onclick: async () => { await api('DELETE', 'link'); clear(); toast(t('Codice annullato.')); } }, t('Annulla il codice')));
      make.hidden = true;
      clearInterval(timer);
      timer = setInterval(() => {
        if (!shown.isConnected) return clearInterval(timer);
        if (Date.now() >= until) {
          clear();
          toast(t('Codice scaduto: creane un altro.'));
        }
      }, 5000);
    } catch (error) {
      toast(error.message, 5000);
    }
  };
  return h('div', { class: 'panel' },
    h('span', {}, t('Per collegare l\'iPhone, l\'iPad o un altro browser senza scrivere la password: crea un codice e inquadra il QR con la fotocamera dell\'iPhone, oppure scrivi il codice nell\'app (Impostazioni → Server → Collega al server → Codice dal sito). Vale 10 minuti e una volta sola.')),
    make, shown,
    h('span', { class: 'sub small' }, t("Oppure, nell'app: Impostazioni → Server, con questo indirizzo, il nome utente e la password.")),
    h('code', { style: 'font-size:16px;color:var(--accent)' }, location.origin));
}

/** The passkeys of the account: add one from this browser, delete one. */
function passkeysPanel() {
  const panel = h('div', { class: 'panel' },
    h('span', {}, t('Con una passkey entri sul sito con Face ID, l\'impronta o il PIN, senza password. Il server tiene solo la chiave pubblica: anche chi copiasse i suoi file non potrebbe entrare.')));
  const list = h('div', {});
  const day = (iso) => fmt(new Date(iso), { day: 'numeric', month: 'short', year: 'numeric' });
  const show = (passkeys) => list.replaceChildren(...(passkeys.length ? passkeys.map((p) => h('div', { class: 'row' },
    h('div', { class: 'grow' }, h('div', {}, '🔑 ', p.name),
      h('div', { class: 'sub small' }, `${p.site} · ${t('Creata')} ${day(p.created)}${p.used ? ` · ${t('Usata')} ${day(p.used)}` : ''}`)),
    h('button', { class: 'btn small danger', type: 'button', onclick: async () => {
      show((await api('DELETE', `passkeys/${encodeURIComponent(p.id)}`)).passkeys);
      toast(t('Passkey eliminata.'));
    } }, t('Elimina')))) : [h('span', { class: 'sub small' }, t('Nessuna passkey.'))]));
  api('GET', 'passkeys').then((r) => show(r.passkeys)).catch(() => {});
  panel.append(list);
  if (canPasskey()) {
    const name = h('input', { type: 'text', placeholder: t('Nome della passkey'), value: deviceName().replace('Browser', 'Passkey'), maxlength: 80 });
    const error = h('div', { class: 'error' });
    panel.append(name, error, h('button', { class: 'btn', type: 'button', onclick: async () => {
      try {
        error.textContent = '';
        show((await addPasskey(name.value)).passkeys);
        state.status.passkeys = true;
        toast(t('Passkey aggiunta: la prossima volta entri senza password.'), 5000);
      } catch (e) {
        error.textContent = passkeyError(e);
      }
    } }, '🔑 ', t('Aggiungi una passkey')));
  } else {
    panel.append(h('span', { class: 'sub small' }, t('Le passkey funzionano aprendo il sito con il suo dominio in https (per esempio quello che usi fuori casa), non con l\'indirizzo della NAS.')));
  }
  return panel;
}

document.getElementById('dialog').addEventListener('click', (event) => {
  if (event.target.id === 'dialog') closeDialog();
});

boot();
