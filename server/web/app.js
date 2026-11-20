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
  'foto': 'photos', 'Sono lo stesso capo visto da più lati, o capi diversi?': 'Are they the same piece seen from more sides, or different pieces?',
  'Un solo capo: fronte, retro…': 'One piece: front, back…', 'Un capo per ogni foto': 'A piece for each photo',
  'Codice di installazione': 'Setup code', 'Lo scrive il server nel suo log al primo avvio (per esempio con docker logs). Serve solo se apri il server da internet.': 'The server writes it in its log when it first starts (for example with docker logs). Only needed when you open the server from the internet.',
  'Aggiungi foto': 'Add photos', 'Descrivi con l\'IA': 'Describe with AI', 'L\'IA sta guardando la foto…': 'The AI is looking at the photo…',
  'Fatto: controlla e salva.': 'Done: check and save.', 'Salvato.': 'Saved.', 'Eliminato.': 'Deleted.',
  'Eliminare questo capo? Le foto vanno via anche dall\'iPhone.': 'Delete this piece? Its photos leave the iPhone too.',
  'Carico le foto…': 'Uploading the photos…', 'capi aggiunti.': 'pieces added.',
  'Riconosci con l\'IA': 'Recognise with AI', 'Tipo, marca, taglia, colori e tessuto, letti dalla foto.': 'Kind, brand, size, colors and fabric, read from the photo.',
  'L\'IA riconosce il capo': 'The AI recognises piece', 'L\'IA non ha risposto:': 'The AI did not answer:', di: 'of',
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
  'Il mio armadio': 'My closet', 'capi nel tuo armadio': 'pieces in your closet', 'Cerca capi…': 'Search pieces…',
  'I tuoi outfit: li ritrovi anche sull\'iPhone.': 'Your outfits: you find them on the iPhone too.',
  'Cosa hai messo, giorno per giorno.': 'What you wore, day by day.', 'Menu': 'Menu', 'outfit': 'outfits',
  'Gestisci il server, l\'IA e l\'accesso.': 'Manage the server, the AI and sign-in.',
  'Un codice per l\'iPhone, l\'iPad o un altro browser, senza scrivere la password.': 'A code for the iPhone, the iPad or another browser, without typing the password.',
  'Intelligenza artificiale': 'Artificial intelligence',
  'L\'Ollama che descrive i capi e risponde all\'app, e il modello da usare.': 'The Ollama that describes pieces and answers the app, and the model to use.',
  'Dove è aperto questo account. Scollegane uno per farlo uscire.': 'Where this account is signed in. Sign one out to end it.',
  'Entra con Face ID, l\'impronta o il PIN al posto della password.': 'Sign in with Face ID, your fingerprint or PIN instead of the password.',
  'Nome utente e password, per il sito e per l\'app.': 'User name and password, for the site and the app.',
  'Accedi per vedere il tuo armadio': 'Sign in to see your closet', 'es. anna': 'e.g. anna',
  'Il tuo armadio, dal server di casa. Lo stesso account vale per l\'app sull\'iPhone.': 'Your closet, from your home server. The same account works for the iPhone app.',
  'Benvenuto': 'Welcome', 'Crea l\'accesso al tuo server ShadowWear': 'Create the sign-in for your ShadowWear server',
  'Almeno 10 caratteri: meglio qualche parola che nessuno indovina.': 'At least 10 characters: a few words nobody would guess are best.',
  'Crea l\'accesso': 'Create sign-in',
  'Il sito e l\'app sull\'iPhone useranno questo nome utente e questa password per collegarsi.': 'The site and the iPhone app will use this user name and password to connect.',
  'Nuova password': 'New password',
  'Indirizzo di Ollama': 'Ollama address', 'Prova': 'Try', 'non trovato': 'not found',
  'Vuoto: quello della NAS': 'Empty: the NAS one', 'Ollama risponde': 'Ollama answers', 'modelli': 'models',
  'Il computer o la NAS dove gira Ollama, con la porta (di solito 11434).': 'The computer or NAS where Ollama runs, with the port (usually 11434).',
  'Scrivi l\'indirizzo del tuo Ollama, per esempio http://192.168.1.10:11434, e premi Prova.': 'Type the address of your Ollama, for example http://192.168.1.10:11434, and press Try.',
  'Ollama risponde ma non ha modelli: scaricane uno che vede le immagini (per esempio qwen2.5vl o gemma3).': 'Ollama answers but has no models: download one that can see images (for example qwen2.5vl or gemma3).',
  'Questo è il modello di chi usa il server. Ogni iPhone può sceglierne un altro, o un\'altra IA, in Impostazioni → Intelligenza artificiale.': 'This is the model for everyone using the server. Each iPhone can choose another one, or another AI, in Settings → Artificial intelligence.',
  'Indirizzo non valido: scrivi per esempio http://192.168.1.10:11434': 'Invalid address: type for example http://192.168.1.10:11434',
  'Il server non ha Ollama: scrivi il suo indirizzo nelle impostazioni del sito.': 'The server has no Ollama: type its address in the site settings.',
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
  "Senza nome": "No name",
  "Cosa comprare": "To buy",
  "da comprare": "to buy",
  "Quello che vuoi comprare, con il link del negozio.": "What you want to buy, with the shop's link.",
  "Prezzo da scrivere": "No price yet",
  "Cosa vuoi comprare?": "What do you want to buy?",
  "Aggiungi un capo con il link del negozio e il prezzo. Nell'app sull'iPhone, \"Controlla i prezzi\" legge le pagine e ti dice se sono scesi.": "Add a piece with the shop's link and the price. In the iPhone app, \"Check prices\" reads the pages and tells you if they went down.",
  "I prezzi li aggiorna l'app sull'iPhone, con \"Controlla i prezzi\": le pagine dei negozi le legge solo il telefono.": "Prices are updated by the iPhone app, with \"Check prices\": only the phone reads the shop pages.",
  "Comprati": "Bought",
  "Nessuno": "None",
  "es. Giacca di jeans": "e.g. Denim jacket",
  "Link del negozio": "Shop link",
  "Prezzo": "Price",
  "Valuta": "Currency",
  "Comprato": "Bought",
  "Apri il negozio": "Open the shop",
  "Il prezzo non è un numero.": "The price is not a number.",
  "Scrivi un nome o incolla il link del negozio.": "Write a name or paste the shop's link.",
  "Da comprare": "To buy",
  "Togliere dalla lista?": "Remove from the list?",
  "1 volta": "once",
  "Statistiche": "Statistics",
  "Cosa metti, cosa no, i colori e quanto ti costa ogni uso.": "What you wear, what you don't, the colors and what each wear costs.",
  "Cosa metti, per tipo": "What you wear, by kind",
  "I colori che metti": "The colors you wear",
  "Ancora nessun dato": "No data yet",
  "Segna nel diario cosa indossi: qui vedrai cosa metti di più, i colori e quanto ti costa ogni uso.": "Note in the diary what you wear: here you will see what you wear most, the colors and what each wear costs.",
  "I colori dell'armadio": "The colors of the closet",
  "Ti piacciono di più": "You like most",
  "Dai giorni con il pollice in su.": "From the days with a thumbs up.",
  "Costo per uso": "Cost per wear",
  "Il prezzo diviso per le volte che l'hai messo. Il prezzo si scrive nella scheda del capo, nell'app.": "The price divided by the times you wore it. The price is written on the piece, in the app.",
  "Valore dell'armadio": "Value of the closet",
  "Mai messo": "Never worn",
  "Mai messi": "Never worn",
  "30 giorni": "30 days",
  "Un anno": "A year",
  "Sempre": "Always",
  "Giorni nel diario": "Days in the diary",
  "Capi messi": "Pieces worn",
  "Prima": "Before",
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
  status: null, items: [], outfits: [], wears: [], wishes: [], photos: new Set(), period: 'all',
  tab: localStorage.getItem('sw-tab') || 'closet',
  category: null, query: '', favorites: false, occasion: null,
  month: monthStart(new Date()), day: dayKey(new Date()),
  user: '', menu: false,
};

// ---------- helpers ----------

// Line icons drawn for ShadowWear (24×24, stroke).
const ICONS = {
  shirt: '<path d="M8 3 4 5.5 2.5 10l3 1.2V21h13v-9.8l3-1.2L20 5.5 16 3c-.5 1.6-2.1 2.6-4 2.6S8.5 4.6 8 3Z"/>',
  grid: '<rect x="3.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="13.5" width="7" height="7" rx="1.5"/>',
  calendar: '<rect x="3.5" y="5" width="17" height="15.5" rx="2"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
  settings: '<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2.2"/><circle cx="10" cy="17" r="2.2"/>',
  logout: '<path d="M15 4h3.5A1.5 1.5 0 0 1 20 5.5v13a1.5 1.5 0 0 1-1.5 1.5H15"/><path d="M10 8l-4 4 4 4M6 12h10"/>',
  menu: '<path d="M4 6h16M4 12h16M4 18h16"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  search: '<circle cx="11" cy="11" r="6.5"/><path d="m16 16 4 4"/>',
  fingerprint: '<path d="M7.5 19.5c1-2 1.5-4.2 1.5-6.5a3 3 0 0 1 6 0c0 1.2-.1 2.4-.3 3.5"/><path d="M12 13c0 3-.7 5.7-2 8"/><path d="M5 16.5c.6-1.2 1-2.3 1-3.5a6 6 0 0 1 10.2-4.3"/><path d="M18.2 11c.2.6.3 1.3.3 2 0 2.5-.4 4.8-1.2 7"/><path d="M4.5 9.5A8.5 8.5 0 0 1 12 4.5c2 0 3.8.7 5.3 1.8"/>',
  sparkles: '<path d="M12 4l1.6 4.4L18 10l-4.4 1.6L12 16l-1.6-4.4L6 10l4.4-1.6Z"/><path d="M19 15l.7 1.8 1.8.7-1.8.7L19 20l-.7-1.8-1.8-.7 1.8-.7Z"/>',
  link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
  devices: '<rect x="3" y="4.5" width="13" height="10" rx="1.5"/><path d="M6.5 18.5h6"/><rect x="17" y="8.5" width="4.5" height="11" rx="1"/>',
  key: '<circle cx="8" cy="15" r="4"/><path d="m11 12 8.5-8.5M16 7l2.5 2.5M14 9l2 2"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4.5 20.5a7.5 7.5 0 0 1 15 0"/>',
  cart: '<path d="M3 4h2.5l2.2 10.5a1.5 1.5 0 0 0 1.5 1.2h8.3a1.5 1.5 0 0 0 1.5-1.1L20.5 8H6.4"/><circle cx="9.5" cy="19.5" r="1.3"/><circle cx="17" cy="19.5" r="1.3"/>',
  chart: '<path d="M4 20.5h16"/><rect x="5.5" y="11" width="3" height="7" rx="1"/><rect x="10.5" y="6" width="3" height="12" rx="1"/><rect x="15.5" y="13.5" width="3" height="4.5" rx="1"/>',
};
const SVG = 'http://www.w3.org/2000/svg';

function icon(name, cls = '') {
  const el = document.createElementNS(SVG, 'svg');
  el.setAttribute('viewBox', '0 0 24 24');
  el.setAttribute('class', `i ${cls}`.trim());
  el.setAttribute('aria-hidden', 'true');
  el.innerHTML = ICONS[name] ?? '';
  return el;
}

/** The title of a page, a line under it and its buttons on the right. */
function pageHead(title, subtitle, ...actions) {
  return h('div', { class: 'page-head' },
    h('div', {}, h('h1', {}, title), subtitle ? h('p', {}, subtitle) : null),
    actions.flat().filter(Boolean).length ? h('div', { class: 'actions' }, actions) : null);
}

/** A card of the settings: a title with its icon, a line that says what it is for, the content. */
function section(symbol, title, text, ...content) {
  return h('section', { class: 'section' },
    h('div', { class: 'section-head' }, h('h3', {}, icon(symbol), title), text ? h('p', {}, text) : null),
    content);
}

function emptyState(symbol, title, text) {
  return h('div', { class: 'empty' }, h('div', { class: 'big' }, icon(symbol)), h('h2', {}, title), text ? h('p', {}, text) : null);
}

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

/** Now as the app writes dates: with milliseconds. */
function isoNow() {
  return new Date().toISOString();
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
  const ask = () => fetch(`/api/${path}`, {
    method,
    credentials: 'same-origin',
    headers: {
      'x-shadowwear': 'web',
      ...(body !== undefined ? { 'content-type': 'application/json' } : {}),
      ...(raw ? { 'content-type': raw.type || 'application/octet-stream' } : {}),
    },
    body: raw ?? (body !== undefined ? JSON.stringify(body) : undefined),
  });
  let res = await ask();
  // 408: a proxy in front of the server gave up receiving the request, so the server never had it:
  // once more is safe and usually goes through.
  if (res.status === 408) {
    await new Promise((resolve) => setTimeout(resolve, 1000));
    res = await ask();
  }
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
  state.wishes = data.wishes ?? [];
  state.photos = new Set(data.photos);
  state.user = await api('GET', 'account').then((a) => a.user ?? '').catch(() => '');
}

function renderMessage(text) {
  document.getElementById('app').replaceChildren(h('p', { class: 'loading' }, text));
}

function render() {
  const app = document.getElementById('app');
  if (!state.status.configured) return app.replaceChildren(h('div', { class: 'auth' }, setupView()));
  if (!state.status.signedIn) return app.replaceChildren(h('div', { class: 'auth' }, loginView()));
  const views = { closet: closetView, outfits: outfitsView, diary: diaryView, wishes: wishlistView, stats: statsView, settings: settingsView };
  const go = (key) => {
    state.tab = key;
    state.menu = false;
    localStorage.setItem('sw-tab', key);
    render();
    window.scrollTo(0, 0);
  };
  const item = ([key, label, symbol]) => h('button', {
    class: `nav-item ${state.tab === key ? 'on' : ''}`, onclick: () => go(key),
  }, icon(symbol), t(label));
  const logout = async () => { await api('POST', 'logout'); location.reload(); };
  app.replaceChildren(
    h('div', { class: `shell ${state.menu ? 'open' : ''}` },
      h('aside', { class: 'sidebar' },
        h('div', { class: 'brand' }, h('img', { src: 'icon.png', alt: '' }), 'ShadowWear'),
        h('nav', { class: 'nav-list' }, [['closet', 'Armadio', 'shirt'], ['outfits', 'Outfit', 'grid'], ['diary', 'Diario', 'calendar'], ['wishes', 'Cosa comprare', 'cart'], ['stats', 'Statistiche', 'chart']].map(item)),
        h('div', { class: 'nav-label' }, t('Impostazioni')),
        h('nav', { class: 'nav-list', style: 'margin-top:0' }, item(['settings', 'Impostazioni', 'settings'])),
        h('div', { class: 'spacer' }),
        h('div', { class: 'foot' }, `${state.items.length} ${t('capi')} · ${state.outfits.length} ${t('outfit')}`)),
      h('div', { class: 'scrim', onclick: () => { state.menu = false; render(); } }),
      h('div', { class: 'page' },
        h('header', { class: 'topbar' },
          h('button', { class: 'icon-btn menu-btn', 'aria-label': t('Menu'), onclick: () => { state.menu = !state.menu; render(); } }, icon('menu')),
          h('div', { class: 'top-brand' }, h('img', { src: 'icon.png', alt: '' }), 'ShadowWear'),
          h('div', { class: 'grow' }),
          h('div', { class: 'sep' }),
          h('div', { class: 'who' },
            h('span', { class: 'avatar', 'aria-hidden': 'true' }, (state.user || 'S').slice(0, 1).toUpperCase()),
            h('span', { class: 'name' }, state.user)),
          h('button', { class: 'icon-btn', title: t('Esci'), 'aria-label': t('Esci'), onclick: logout }, icon('logout'))),
        h('main', {}, (views[state.tab] ?? closetView)()))));
}

function setupView() {
  const user = h('input', { type: 'text', placeholder: t('es. anna'), autocomplete: 'username', autocapitalize: 'none', spellcheck: 'false', autofocus: true, required: true });
  const one = h('input', { type: 'password', autocomplete: 'new-password', required: true });
  const two = h('input', { type: 'password', autocomplete: 'new-password', required: true });
  // Opened from the internet: the code the server wrote in its log.
  const code = state.status.needsSetupCode ? h('input', { type: 'text', autocomplete: 'off', autocapitalize: 'characters', spellcheck: 'false', required: true }) : null;
  const error = h('div', { class: 'error' });
  const go = async (event) => {
    event.preventDefault();
    if (one.value !== two.value) return (error.textContent = t('Le password non sono uguali.'));
    try {
      await api('POST', 'setup', { user: user.value, password: one.value, device: deviceName(), setupCode: code?.value });
      state.status = await api('GET', 'status');
      await load();
      render();
    } catch (e) {
      error.textContent = e.message;
    }
  };
  return h('form', { class: 'login', onsubmit: go },
    h('div', { class: 'logo' }, h('img', { src: 'icon.png', alt: '' })),
    h('h1', {}, t('Benvenuto')),
    h('p', { class: 'lead' }, t('Crea l\'accesso al tuo server ShadowWear')),
    field(t('Nome utente'), user),
    field(t('Password'), one, h('span', { class: 'sub small' }, t('Almeno 10 caratteri: meglio qualche parola che nessuno indovina.'))),
    field(t('Ripeti la password'), two),
    code ? field(t('Codice di installazione'), code, h('span', { class: 'sub small' }, t('Lo scrive il server nel suo log al primo avvio (per esempio con docker logs). Serve solo se apri il server da internet.'))) : null,
    error,
    h('button', { class: 'btn primary wide', type: 'submit' }, t('Crea l\'accesso')),
    h('p', { class: 'note' }, t('Il sito e l\'app sull\'iPhone useranno questo nome utente e questa password per collegarsi.')));
}

function loginView() {
  const user = h('input', { type: 'text', placeholder: t('es. anna'), autocomplete: 'username webauthn', autocapitalize: 'none', spellcheck: 'false', autofocus: true, required: true });
  const password = h('input', { type: 'password', autocomplete: 'current-password', required: true });
  const error = h('div', { class: 'error', role: 'alert' });
  const submit = h('button', { class: 'btn primary wide', type: 'submit' }, t('Accedi'));
  const go = async (event) => {
    event.preventDefault();
    error.textContent = '';
    submit.disabled = true;
    try {
      await api('POST', 'login', { user: user.value.trim(), password: password.value, device: deviceName() });
      state.status = await api('GET', 'status');
      await load();
      render();
    } catch (e) {
      error.textContent = e.message;
      password.select();
    } finally {
      submit.disabled = false;
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
    h('div', { class: 'logo' }, h('img', { src: 'icon.png', alt: '' })),
    h('h1', {}, t('Accedi')),
    h('p', { class: 'lead' }, t('Accedi per vedere il tuo armadio')),
    field(t('Nome utente'), user),
    field(t('Password'), password),
    error,
    submit,
    withPasskey ? [h('div', { class: 'divider' }, t('oppure')),
      h('button', { class: 'btn wide', type: 'button', onclick: passkey }, icon('fingerprint', 'sm'), t('Accedi con una passkey'))] : null,
    h('p', { class: 'note' }, t('Il tuo armadio, dal server di casa. Lo stesso account vale per l\'app sull\'iPhone.')));
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

  const search = h('input', { type: 'search', class: 'grow', placeholder: t('Cerca capi…'), value: state.query });
  search.addEventListener('input', () => {
    state.query = search.value;
    const grid = document.getElementById('closet-grid');
    grid?.replaceWith(closetGrid(closetFiltered()));
  });
  const file = h('input', { type: 'file', accept: 'image/*', multiple: true, hidden: true, onchange: () => { choosePhotos([...file.files]); file.value = ''; } });
  // The same tick as on the iPhone: the AI recognises each new piece while the photos go up.
  const tick = aiReady() ? h('label', { class: 'row tick', title: t('Tipo, marca, taglia, colori e tessuto, letti dalla foto.') },
    h('input', { type: 'checkbox', checked: aiTag(), onchange: (e) => setAiTag(e.target.checked) }), '✦ ', t('Riconosci con l\'IA')) : null;

  return h('div', {},
    pageHead(t('Il mio armadio'), `${state.items.length} ${t('capi nel tuo armadio')}`,
      h('button', { class: 'btn primary', onclick: () => file.click() }, icon('plus', 'sm'), t('Aggiungi capi'))),
    h('div', { class: 'bar' }, search, tick, file),
    state.items.length ? h('div', { class: 'chips' },
      h('button', { class: `chip ${!state.category ? 'on' : ''}`, onclick: () => { state.category = null; render(); } }, t('Tutti'), h('span', { class: 'n' }, state.items.length)),
      CATEGORIES.filter(([k]) => counts[k]).map(([k, label]) => h('button', {
        class: `chip ${state.category === k ? 'on' : ''}`,
        onclick: () => { state.category = state.category === k ? null : k; render(); },
      }, t(label), h('span', { class: 'n' }, counts[k]))),
      h('button', { class: `chip ${state.favorites ? 'on' : ''}`, onclick: () => { state.favorites = !state.favorites; render(); } }, '★ ', t('Preferiti'))) : null,
    h('div', { style: 'height:12px' }),
    state.items.length ? closetGrid(shown)
      : emptyState('shirt', t('Il tuo armadio è vuoto'), t('Aggiungi le foto dei capi da qui, oppure dall\'app sull\'iPhone: si sincronizzano da sole.')));
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
      h('div', { class: 'row', style: 'gap:6px' },
        h('div', { class: 'name grow' }, displayName(item)),
        (item.colors ?? []).slice(0, 2).map((c) => COLOR[c] ? h('span', { class: 'dot', title: t(COLOR[c].name), style: `background:${COLOR[c].rgb}` }) : null)),
      h('div', { class: 'line' }, [item.brand, item.size].filter(Boolean).join(' · ') || t(CATEGORY[item.category]?.label ?? '')),
      h('div', {}, h('span', { class: 'badge' }, icon('shirt', 'xs'), t(CATEGORY[item.category]?.name ?? '')))))));
}

/** Whether the server's AI can describe pieces: an Ollama and a model chosen. */
function aiReady() {
  return Boolean(state.status.ai?.available && state.status.ai?.model);
}

/** The tick "Riconosci con l'IA", on by default, remembered in this browser. */
function aiTag() {
  try { return localStorage.getItem('sw-ai-tag') !== '0'; } catch { return true; }
}

function setAiTag(on) {
  try { localStorage.setItem('sw-ai-tag', on ? '1' : '0'); } catch { /* private window: on for this page only */ }
}

/** Several photos: one piece seen from more sides (front, back…) or a piece each, as on the iPhone. */
function choosePhotos(files) {
  if (files.length < 2) return addPhotos(files);
  dialog(`${files.length} ${t('foto')}`, h('div', { class: 'choose' },
    h('p', { class: 'sub' }, t('Sono lo stesso capo visto da più lati, o capi diversi?')),
    h('button', { class: 'btn primary', onclick: () => { closeDialog(); addPhotos(files, true); } }, t('Un solo capo: fronte, retro…')),
    h('button', { class: 'btn', onclick: () => { closeDialog(); addPhotos(files, false); } }, t('Un capo per ogni foto'))),
  [h('button', { class: 'btn', onclick: closeDialog }, t('Annulla'))]);
}

/** Photos from the computer: each becomes a piece (as on the iPhone), or all go to one piece
 * (`together`: the first is the cover). The colors are guessed here, and with the tick on the AI
 * recognises each piece before it is saved. */
async function addPhotos(files, together = false) {
  if (!files.length) return;
  const recognise = aiReady() && aiTag();
  toast(t('Carico le foto…'), 60_000);
  let last = null;
  let done = 0;
  let aiProblem = null;
  let piece = null;
  for (const [index, file] of files.entries()) {
    try {
      const { blob, colors } = await prepare(file);
      const photo = { id: uuid(), hasCutout: false, showCutout: true };
      await api('PUT', `photos/${photo.id}.jpg`, undefined, blob);
      if (together && piece) {
        // The back, a detail: one more photo of the same piece.
        piece.photos.push(photo);
        piece.updated = isoNow();
        await api('PUT', `items/${piece.id}`, piece);
        continue;
      }
      const now = isoNow();
      const item = { id: uuid(), name: '', category: 'other', colors, brand: '', size: '', notes: '', favorite: false, photos: [photo], created: now, updated: now };
      // After two failures the AI is not there: no use waiting on the next ones.
      if (recognise && (!aiProblem || aiProblem.count < 2)) {
        toast(files.length > 1 && !together ? `${t('L\'IA riconosce il capo')} ${index + 1} ${t('di')} ${files.length}…` : `${t('L\'IA riconosce il capo')}…`, 300_000);
        try {
          applyAnswer(item, await api('POST', `ai/describe?lang=${IT ? 'it' : 'en'}`, undefined, blob));
          // The colors measured on the photo are kept when there are some.
          if (colors.length) item.colors = colors;
        } catch (error) {
          aiProblem = { message: error.message, count: (aiProblem?.count ?? 0) + 1 };
        }
      }
      await api('PUT', `items/${item.id}`, item);
      piece = item;
      last = item.id;
      done += 1;
    } catch (error) {
      toast(error.message, 5000);
    }
  }
  await load();
  render();
  toast(aiProblem ? `${t('L\'IA non ha risposto:')} ${aiProblem.message}`
    : `${done} ${t('capi aggiunti.')} ${t('Lo sfondo lo toglie l\'app sull\'iPhone (Togli lo sfondo, nel menu della foto).')}`, 6000);
  if (last) openItem(last);
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
    applyAnswer(item, await api('POST', `ai/describe?lang=${IT ? 'it' : 'en'}`, undefined, image));
    draw();
    busy.replaceChildren(t('Fatto: controlla e salva.'));
  } catch (error) {
    busy.replaceChildren(h('span', { class: 'error' }, error.message));
  }
}

/** The AI's description put into a piece. Brand and size only when it could read them, and never over what was written. */
function applyAnswer(item, answer) {
  if (answer.name) item.name = answer.name;
  item.category = answer.category ?? item.category;
  if (answer.colors?.length) item.colors = answer.colors;
  if (answer.warmth !== null && answer.warmth !== undefined) item.warmth = answer.warmth;
  if (answer.brand && !item.brand) item.brand = answer.brand;
  if (answer.size && !item.size) item.size = answer.size;
  const extra = [answer.material, answer.style].filter(Boolean).join(', ');
  const notes = [extra, answer.notes].filter(Boolean).join('. ');
  if (notes && !item.notes) item.notes = notes;
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
    pageHead(t('Outfit'), t('I tuoi outfit: li ritrovi anche sull\'iPhone.'),
      h('button', { class: 'btn primary', disabled: !state.items.length, onclick: () => openOutfit(null) }, icon('plus', 'sm'), t('Nuovo outfit'))),
    h('div', { class: 'bar' },
      h('div', { class: 'chips grow' },
        h('button', { class: `chip ${!state.occasion ? 'on' : ''}`, onclick: () => { state.occasion = null; render(); } }, t('Tutti'), h('span', { class: 'n' }, state.outfits.length)),
        OCCASIONS.filter(([k]) => state.outfits.some((o) => o.occasion === k)).map(([k, label]) => h('button', {
          class: `chip ${state.occasion === k ? 'on' : ''}`, onclick: () => { state.occasion = state.occasion === k ? null : k; render(); },
        }, t(label))))),
    shown.length ? h('div', { class: 'grid' }, shown.map((outfit) => h('button', { class: 'card', onclick: () => openOutfit(outfit.id) },
      collage(piecesOf(outfit.items)),
      outfit.favorite ? h('span', { class: 'star' }, '★') : null,
      h('div', { class: 'meta' },
        h('div', { class: 'name' }, outfitName(outfit)),
        h('div', { class: 'line' }, outfit.occasion ? t(OCCASION[outfit.occasion]) : `${piecesOf(outfit.items).length} ${t('capi')}`)))))
      : emptyState('grid', t('Nessun outfit'), t('Metti insieme i capi dell\'armadio: li ritrovi qui e sull\'iPhone.')));
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
    pageHead(t('Diario'), t('Cosa hai messo, giorno per giorno.')),
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

/** The server's AI: the address of Ollama (tried before it is saved), the model and the language.
 * Each iPhone can still choose another model of this Ollama, or another AI, in its own settings. */
function aiPanel(ai) {
  const holder = h('div', { style: 'display:flex;flex-direction:column;gap:6px' }, h('span', { class: 'sub' }, t('Carico i modelli…')));
  ai.append(holder);
  api('GET', 'settings').then((settings) => {
    const address = h('input', { type: 'text', placeholder: settings.ollamaDefault || 'http://192.168.1.10:11434', value: settings.ollamaURL || '' });
    address.setAttribute('autocomplete', 'off');
    address.setAttribute('spellcheck', 'false');
    const select = h('select', {}, h('option', { value: '' }, '—'));
    const lang = h('select', {},
      h('option', { value: 'it', selected: settings.language === 'it' }, t('Italiano')),
      h('option', { value: 'en', selected: settings.language === 'en' }, t('Inglese')));
    const note = h('span', { class: 'sub small' });
    const tryButton = h('button', { class: 'btn small', type: 'button' }, t('Prova'));
    const saveButton = h('button', { class: 'btn primary small', type: 'button' }, t('Salva'));
    let current = settings.aiModel || '';

    const fill = (models) => {
      select.replaceChildren(h('option', { value: '' }, '—'),
        ...models.map((m) => h('option', { value: m.name, selected: m.name === current }, `${m.vision ? '👁 ' : ''}${m.name}`)));
      if (current && !models.some((m) => m.name === current)) {
        select.append(h('option', { value: current, selected: true }, `${current} (${t('non trovato')})`));
      }
    };
    const load = async () => {
      const typed = address.value.trim() || settings.ollamaDefault || '';
      if (!typed) {
        fill([]);
        note.className = 'sub small';
        note.textContent = t('Scrivi l\'indirizzo del tuo Ollama, per esempio http://192.168.1.10:11434, e premi Prova.');
        return;
      }
      tryButton.disabled = true;
      note.className = 'sub small';
      note.textContent = t('Carico i modelli…');
      try {
        const found = await api('GET', `ai/models?url=${encodeURIComponent(typed)}`);
        fill(found.models);
        note.textContent = found.models.length
          ? `${t('Ollama risponde')} (${found.url}): ${found.models.length} ${t('modelli')}.`
          : t('Ollama risponde ma non ha modelli: scaricane uno che vede le immagini (per esempio qwen2.5vl o gemma3).');
      } catch (error) {
        fill([]);
        note.className = 'error small';
        note.textContent = error.message;
      } finally {
        tryButton.disabled = false;
      }
    };
    const save = async () => {
      saveButton.disabled = true;
      try {
        const saved = await api('PUT', 'settings', { ollamaURL: address.value.trim(), aiModel: select.value, language: lang.value });
        current = saved.aiModel || '';
        address.value = saved.ollamaURL || '';
        state.status.ai = { available: Boolean(saved.ollamaInUse), model: saved.aiModel || null };
        toast(t('Salvato.'));
      } catch (error) {
        note.className = 'error small';
        note.textContent = error.message;
      } finally {
        saveButton.disabled = false;
      }
    };
    tryButton.onclick = load;
    saveButton.onclick = save;
    address.addEventListener('keydown', (event) => { if (event.key === 'Enter') { event.preventDefault(); load(); } });

    holder.replaceChildren(
      field(t('Indirizzo di Ollama'), h('div', { class: 'row' }, h('div', { class: 'grow' }, address), tryButton),
        h('span', { class: 'sub small' }, settings.ollamaDefault
          ? `${t('Vuoto: quello della NAS')} (${settings.ollamaDefault}).`
          : t('Il computer o la NAS dove gira Ollama, con la porta (di solito 11434).'))),
      note,
      field(t('Modello'), select, h('span', { class: 'sub small' }, t('Scegli un modello che vede le immagini (segnato con 👁).'))),
      field(t('Lingua delle descrizioni'), lang),
      h('div', { class: 'row' }, saveButton),
      h('span', { class: 'sub small' }, t('Questo è il modello di chi usa il server. Ogni iPhone può sceglierne un altro, o un\'altra IA, in Impostazioni → Intelligenza artificiale.')));
    address.style.width = '100%';
    load();
  }).catch(() => holder.replaceChildren(h('span', { class: 'error' }, t('Ollama non risponde.'))));
}

// ---------- what to buy ----------

const CURRENCIES = ['EUR', 'USD', 'GBP', 'CHF'];

/** A price as the shop writes it: 49,90 €. */
function money(value, currency = 'EUR') {
  try {
    return new Intl.NumberFormat(IT ? 'it-IT' : 'en-GB', { style: 'currency', currency: currency || 'EUR' }).format(value);
  } catch {
    return `${value} ${currency || ''}`.trim();
  }
}

function wishTitle(wish) {
  const title = wish.title?.trim();
  if (title) return title;
  try { return new URL(wish.link).host; } catch { return t('Senza nome'); }
}

/** Only http(s) addresses become links or pictures. */
function webURL(text) {
  try {
    const url = new URL(String(text ?? '').trim());
    return ['http:', 'https:'].includes(url.protocol) ? url.href : null;
  } catch {
    return null;
  }
}

/** Down, up or the same since the shop page was read before. */
function trend(wish) {
  if (typeof wish.price !== 'number' || typeof wish.previousPrice !== 'number' || wish.price === wish.previousPrice) return 0;
  return wish.price < wish.previousPrice ? -1 : 1;
}

function wishlistView() {
  const open = state.wishes.filter((w) => !w.bought).sort((a, b) => (b.created ?? '').localeCompare(a.created ?? ''));
  const bought = state.wishes.filter((w) => w.bought).sort((a, b) => (b.updated ?? '').localeCompare(a.updated ?? ''));
  const add = () => openWish({ id: uuid(), title: '', link: '', image: '', currency: 'EUR', notes: '', bought: false }, true);
  return h('div', {},
    pageHead(t('Cosa comprare'), open.length ? `${open.length} ${t('da comprare')}` : t('Quello che vuoi comprare, con il link del negozio.'),
      h('button', { class: 'btn primary', onclick: add }, icon('plus', 'sm'), t('Aggiungi'))),
    open.length ? h('div', { class: 'grid' }, open.map((wish) => {
      const image = webURL(wish.image);
      const move = trend(wish);
      return h('button', { class: 'card', onclick: () => openWish(structuredClone(wish)) },
        h('div', { class: 'pic' }, image ? h('img', { src: image, alt: '', loading: 'lazy', referrerpolicy: 'no-referrer' }) : icon('cart', 'lg')),
        h('div', { class: 'meta' },
          h('div', { class: 'name' }, wishTitle(wish)),
          h('div', { class: 'line' },
            typeof wish.price === 'number' ? h('span', { class: 'price' }, money(wish.price, wish.currency)) : h('span', {}, t('Prezzo da scrivere')),
            move ? h('span', { class: `trend ${move < 0 ? 'down' : 'up'}`, title: t('Prima') + ' ' + money(wish.previousPrice, wish.currency) }, move < 0 ? '↓ ' : '↑ ', h('s', {}, money(wish.previousPrice, wish.currency))) : null),
          wish.category ? h('div', { class: 'line' }, h('span', { class: 'badge' }, t(CATEGORY[wish.category]?.label ?? ''))) : null));
    }))
      : emptyState('cart', t('Cosa vuoi comprare?'), t('Aggiungi un capo con il link del negozio e il prezzo. Nell\'app sull\'iPhone, "Controlla i prezzi" legge le pagine e ti dice se sono scesi.')),
    open.some((w) => webURL(w.link)) ? h('p', { class: 'sub small', style: 'margin-top:14px' }, t('I prezzi li aggiorna l\'app sull\'iPhone, con "Controlla i prezzi": le pagine dei negozi le legge solo il telefono.')) : null,
    bought.length ? h('details', { class: 'bought' },
      h('summary', {}, `${t('Comprati')}: ${bought.length}`),
      bought.map((wish) => h('button', { class: 'bought-row', onclick: () => openWish(structuredClone(wish)) },
        h('span', { class: 'grow' }, wishTitle(wish)),
        typeof wish.price === 'number' ? h('span', { class: 'sub' }, money(wish.price, wish.currency)) : null))) : null);
}

function openWish(wish, isNew = false) {
  const before = wish.price;
  const text = (key, placeholder, type = 'text') => {
    const el = h('input', { type, placeholder, value: wish[key] ?? '' });
    el.addEventListener('input', () => { wish[key] = el.value; });
    return el;
  };
  const price = h('input', { type: 'text', inputmode: 'decimal', placeholder: '49,90', value: typeof wish.price === 'number' ? (Number.isInteger(wish.price) ? String(wish.price) : wish.price.toFixed(2)).replace('.', IT ? ',' : '.') : '' });
  const currency = h('select', {}, CURRENCIES.map((c) => h('option', { value: c }, c)));
  currency.value = CURRENCIES.includes(wish.currency) ? wish.currency : 'EUR';
  const notes = h('textarea', {});
  notes.value = wish.notes ?? '';
  const error = h('p', { class: 'error small' });
  const shop = webURL(wish.link);
  const kinds = () => h('div', { class: 'kinds' },
    h('button', { type: 'button', class: `kind ${!wish.category ? 'on' : ''}`, onclick: () => { delete wish.category; redraw(); } }, t('Nessuno')),
    CATEGORIES.map(([k, label]) => h('button', { type: 'button', class: `kind ${wish.category === k ? 'on' : ''}`, onclick: () => { wish.category = k; redraw(); } }, t(label))));
  const kindBox = h('div', {}, kinds());
  const redraw = () => kindBox.replaceChildren(kinds());
  const body = h('div', { class: 'stack' },
    field(t('Nome'), text('title', t('es. Giacca di jeans'))),
    field(t('Link del negozio'), text('link', 'https://…', 'url')),
    h('div', { class: 'two' }, field(t('Prezzo'), price), field(t('Valuta'), currency)),
    field(t('Tipo'), kindBox),
    field(t('Note'), notes),
    h('label', { class: 'row' }, h('input', { type: 'checkbox', checked: Boolean(wish.bought), onchange: (e) => { wish.bought = e.target.checked; } }), t('Comprato')),
    error,
    h('div', { class: 'bar' },
      shop ? h('a', { class: 'btn', href: shop, target: '_blank', rel: 'noopener noreferrer' }, icon('link', 'sm'), t('Apri il negozio')) : null,
      h('div', { class: 'grow' }),
      isNew ? null : h('button', { class: 'btn danger', onclick: () => deleteWish(wish) }, t('Elimina'))));
  const save = async () => {
    const typed = price.value.trim();
    let value = null;
    if (typed) {
      value = Number(typed.replace(/\s/g, '').replace(/\.(?=\d{3}(\D|$))/g, '').replace(',', '.'));
      if (!Number.isFinite(value) || value < 0) {
        error.textContent = t('Il prezzo non è un numero.');
        return;
      }
    }
    if (!wish.title?.trim() && !webURL(wish.link)) {
      error.textContent = t('Scrivi un nome o incolla il link del negozio.');
      return;
    }
    if (value === null) delete wish.price;
    else {
      // A price changed by hand counts as a change, as when the app reads the page again.
      if (typeof before === 'number' && before !== value) wish.previousPrice = before;
      wish.price = value;
    }
    wish.currency = currency.value;
    wish.notes = notes.value;
    wish.title = wish.title?.trim() ?? '';
    wish.link = wish.link?.trim() ?? '';
    try {
      await api('PUT', `wishes/${wish.id}`, wish);
      await load();
      closeDialog();
      render();
      toast(t('Salvato.'));
    } catch (e) {
      error.textContent = e.message;
    }
  };
  dialog(isNew ? t('Da comprare') : wishTitle(wish), body, [
    h('button', { class: 'btn', onclick: closeDialog }, t('Annulla')),
    h('button', { class: 'btn primary', onclick: save }, t('Salva')),
  ]);
}

async function deleteWish(wish) {
  if (!confirm(t('Togliere dalla lista?'))) return;
  try {
    await api('DELETE', `wishes/${wish.id}`);
    await load();
    closeDialog();
    render();
  } catch (e) {
    toast(e.message, 5000);
  }
}

// ---------- statistics ----------

const PERIODS = [['month', '30 giorni'], ['year', 'Un anno'], ['all', 'Sempre']];

/** The same numbers as the app: what is worn, the colors, what is liked and the cost per wear. */
function computeStats(since) {
  const period = state.wears.filter((w) => !since || w.day >= since);
  const id = (x) => String(x).toUpperCase();
  const byID = new Map(state.items.map((i) => [id(i.id), i]));
  const daysOf = (wears) => {
    const out = new Map();
    for (const w of wears) for (const i of w.items ?? []) {
      if (!out.has(id(i))) out.set(id(i), new Set());
      out.get(id(i)).add(w.day);
    }
    return out;
  };
  const times = daysOf(period);
  const allTimes = daysOf(state.wears);
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
  for (const item of state.items) if (item.colors?.[0]) owned[item.colors[0]] = (owned[item.colors[0]] ?? 0) + 1;
  const counts = (o) => Object.entries(o).map(([key, count]) => ({ key, count })).sort((a, b) => b.count - a.count || a.key.localeCompare(b.key));
  const liking = {};
  for (const w of state.wears) {
    if (!w.rating) continue;
    for (const i of w.items ?? []) liking[id(i)] = (liking[id(i)] ?? 0) + (w.rating > 0 ? 1 : -1);
  }
  worn.sort((a, b) => b.times - a.times || displayName(a.item).localeCompare(displayName(b.item)));
  return {
    pieces: state.items.length,
    daysWritten: new Set(period.map((w) => w.day)).size,
    wornPieces: worn.length,
    neverWorn: state.items.filter((i) => !(allTimes.get(id(i.id))?.size)),
    byCategory: counts(categories),
    byColor: counts(colors),
    closetColors: counts(owned),
    mostWorn: worn.slice(0, 5),
    liked: Object.entries(liking).filter(([, v]) => v > 0).sort((a, b) => b[1] - a[1]).map(([k]) => byID.get(k)).filter(Boolean).slice(0, 5),
    closetValue: state.items.reduce((sum, i) => sum + (typeof i.price === 'number' ? i.price : 0), 0),
    costPerWear: state.items.filter((i) => typeof i.price === 'number' && i.price > 0).map((item) => {
      const n = allTimes.get(id(item.id))?.size ?? 0;
      return { item, times: n, cost: n ? item.price / n : item.price };
    }).sort((a, b) => b.cost - a.cost),
  };
}

function statsView() {
  const since = state.period === 'month' ? dayKey(new Date(Date.now() - 30 * 864e5))
    : state.period === 'year' ? dayKey(new Date(new Date().setFullYear(new Date().getFullYear() - 1))) : null;
  const s = computeStats(since);
  const tile = (value, label) => h('div', { class: 'tile' }, h('div', { class: 'value' }, value), h('div', { class: 'sub small' }, t(label)));
  const pieceRow = (item, detail, right) => h('button', { class: 'piece-row', onclick: () => openItem(item.id) },
    h('div', { class: 'thumb' }, cover(item)),
    h('div', { class: 'grow' }, h('div', { class: 'name' }, displayName(item)), h('div', { class: 'sub small' }, detail)),
    right);
  const colorBar = (list) => {
    const total = Math.max(1, list.reduce((a, c) => a + c.count, 0));
    return h('div', { class: 'stack', style: 'gap:10px' },
      h('div', { class: 'colorbar' }, list.map((c) => h('span', { style: `flex:${c.count};background:${COLOR[c.key]?.rgb ?? 'var(--sub)'}`, title: t(COLOR[c.key]?.name ?? c.key) }))),
      h('div', { class: 'legend' }, list.slice(0, 8).map((c) => h('span', {},
        h('i', { class: 'dot', style: `background:${COLOR[c.key]?.rgb ?? 'var(--sub)'}` }), `${t(COLOR[c.key]?.name ?? c.key)} ${Math.round(c.count / total * 100)}%`))));
  };
  const times = (n) => (n === 1 ? t('1 volta') : `${n} ${t('volte')}`);
  const top = Math.max(1, ...s.byCategory.map((c) => c.count));
  return h('div', {},
    pageHead(t('Statistiche'), t('Cosa metti, cosa no, i colori e quanto ti costa ogni uso.'),
      h('div', { class: 'segmented' }, PERIODS.map(([key, label]) => h('button', {
        type: 'button', class: state.period === key ? 'on' : '', onclick: () => { state.period = key; render(); },
      }, t(label))))),
    h('div', { class: 'tiles' },
      tile(String(s.pieces), 'Capi'),
      tile(String(s.daysWritten), 'Giorni nel diario'),
      tile(s.pieces ? `${Math.round(s.wornPieces / s.pieces * 100)}%` : '—', 'Capi messi'),
      tile(String(s.neverWorn.length), 'Mai messi')),
    h('div', { class: 'stats' },
      s.byCategory.length ? [
        section('shirt', t('Cosa metti, per tipo'), null, s.byCategory.map((c) => h('div', { class: 'hbar' },
          h('div', { class: 'row' }, h('span', { class: 'grow' }, t(CATEGORY[c.key]?.label ?? c.key)), h('span', { class: 'sub' }, c.count)),
          h('div', { class: 'track' }, h('div', { class: 'fill', style: `width:${c.count / top * 100}%` }))))),
        section('sparkles', t('I colori che metti'), null, colorBar(s.byColor)),
      ] : h('div', { class: 'wide' }, emptyState('chart', t('Ancora nessun dato'), t('Segna nel diario cosa indossi: qui vedrai cosa metti di più, i colori e quanto ti costa ogni uso.'))),
      s.closetColors.length ? section('grid', t('I colori dell\'armadio'), null, colorBar(s.closetColors)) : null,
      s.mostWorn.length ? section('calendar', t('I più messi'), null, s.mostWorn.map((e) => pieceRow(e.item, times(e.times)))) : null,
      s.liked.length ? section('sparkles', t('Ti piacciono di più'), t('Dai giorni con il pollice in su.'), s.liked.map((item) => pieceRow(item, t(CATEGORY[item.category]?.label ?? '')))) : null,
      s.costPerWear.length ? section('cart', t('Costo per uso'), t('Il prezzo diviso per le volte che l\'hai messo. Il prezzo si scrive nella scheda del capo, nell\'app.'),
        h('div', { class: 'info' }, h('span', {}, t('Valore dell\'armadio')), h('strong', {}, money(s.closetValue))),
        s.costPerWear.slice(0, 8).map((e) => pieceRow(e.item, e.times ? `${t('Messo')} ${times(e.times)}` : t('Mai messo'),
          h('strong', { class: e.times ? '' : 'warn' }, money(e.cost))))) : null,
      s.neverWorn.length ? section('shirt', t('Mai messi'), null, h('div', { class: 'thumbs' }, s.neverWorn.map((item) => h('button', {
        class: 'thumb', title: displayName(item), onclick: () => openItem(item.id),
      }, cover(item))))) : null));
}

function settingsView() {
  const box = h('div', { class: 'stack' });
  const ai = h('div', { class: 'panel' }, h('strong', {}, t('IA')));
  const devices = h('div', { class: 'panel' }, h('strong', {}, t('Dispositivi collegati')));
  const VIA = { password: 'con la password', passkey: 'con una passkey', codice: 'con un codice' };

  aiPanel(ai);

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
    pageHead(t('Impostazioni'), t('Gestisci il server, l\'IA e l\'accesso.')),
    section('link', t('Collega un dispositivo'), t('Un codice per l\'iPhone, l\'iPad o un altro browser, senza scrivere la password.'), linkPanel()),
    section('sparkles', t('Intelligenza artificiale'), t('L\'Ollama che descrive i capi e risponde all\'app, e il modello da usare.'), ai),
    section('devices', t('Dispositivi collegati'), t('Dove è aperto questo account. Scollegane uno per farlo uscire.'), devices),
    section('fingerprint', t('Passkey'), t('Entra con Face ID, l\'impronta o il PIN al posto della password.'), passkeysPanel()),
    section('user', t('Account'), t('Nome utente e password, per il sito e per l\'app.'),
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
    } }, h('div', { class: 'two' }, field(t('Nome utente'), userName), field(t('Password attuale'), current)),
      field(t('Nuova password'), next), passError, h('div', {}, h('button', { class: 'btn primary', type: 'submit' }, t('Salva'))))),
    h('div', { class: 'bar' },
      h('span', { class: 'sub small grow' }, `${t('Versione del server')}: ${state.status.version}`),
      h('button', { class: 'btn', onclick: async () => { await api('POST', 'logout'); location.reload(); } }, icon('logout', 'sm'), t('Esci'))));
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
    h('div', { class: 'grow' }, h('div', { style: 'font-weight:600' }, p.name),
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
    panel.append(h('div', { class: 'row' }, h('div', { class: 'grow' }, name), h('button', { class: 'btn primary', type: 'button', onclick: async () => {
      try {
        error.textContent = '';
        show((await addPasskey(name.value)).passkeys);
        state.status.passkeys = true;
        toast(t('Passkey aggiunta: la prossima volta entri senza password.'), 5000);
      } catch (e) {
        error.textContent = passkeyError(e);
      }
    } }, icon('fingerprint', 'sm'), t('Aggiungi una passkey'))), error);
  } else {
    panel.append(h('span', { class: 'sub small' }, t('Le passkey funzionano aprendo il sito con il suo dominio in https (per esempio quello che usi fuori casa), non con l\'indirizzo della NAS.')));
  }
  return panel;
}

document.getElementById('dialog').addEventListener('click', (event) => {
  if (event.target.id === 'dialog') closeDialog();
});

boot();
