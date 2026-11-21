// ShadowWear on the computer: the same closet as the iPhone app, from the server on the NAS.
// No libraries but a tiny QR maker (qr.mjs); the page is built with DOM calls only (never innerHTML with data).

import { generate as makeQR } from './qr.mjs';
import {
  SEASONS, addDays, band, clearOut, conditionsOf, dayKey, fromKey, idle, lastWorn, laundry, mentioned, packingLines,
  packingPlan, packingReminders, rainy, readable, recapYears, seasonSwap, seasonsOf, seedFor, spending, stats, suggestions,
  up, warmthOf, yearRecap,
} from './logic.mjs';

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
  // 0.8.0: today, the stylist, the suitcase, laundry, seasons, the clear-out, the looks.
  "Strumenti": "Tools", "Stylist": "Stylist", "Valigia": "Suitcase", "Da lavare": "To wash",
  "Cambio di stagione": "Change of season", "Pulizia dell'armadio": "Closet clear-out",
  "Un'idea di cosa mettere, con il meteo di oggi.": "An idea of what to wear, with today's weather.",
  "Il tuo armadio è vuoto: aggiungi i capi e qui trovi ogni giorno un'idea di cosa mettere, col meteo.": "Your closet is empty: add your pieces and every day you find an idea of what to wear here, with the weather.",
  "Per avere un'idea al giorno servono almeno una maglia e dei pantaloni, oppure un vestito.": "For an idea a day you need at least a top and trousers, or a dress.",
  "Vai all'armadio": "Go to the closet", "Nuova combinazione": "New combination", "Lo metto oggi": "I wear it today",
  "Un'altra idea": "Another idea", "Apri l'outfit": "Open the outfit", "Salva come outfit": "Save as an outfit",
  "Oggi hai messo": "Worn today", "Mi è piaciuto": "I liked it", "Non mi è piaciuto": "I did not like it", "Togli dal diario": "Remove from the diary",
  "Capi messi abbastanza volte dall'ultimo lavaggio.": "Pieces worn enough times since their last wash.", "Vedi cosa lavare": "See what to wash",
  "Meteo": "Weather", "Scegli la tua città: le idee del giorno tengono conto del tempo che fa.": "Choose your town: the ideas of the day take the weather into account.",
  "Scegli la città": "Choose the town", "Carico il meteo…": "Loading the weather…", "La tua città": "Your town",
  "Per esempio Lisbona": "For example Lisbon", "Nessuna città con questo nome.": "No town with this name.",
  "Il meteo arriva da Open-Meteo: il server gli manda solo il nome che cerchi e la posizione della città. La città resta in questo browser.": "The weather comes from Open-Meteo: the server sends it only the name you search for and the position of the town. The town stays in this browser.",
  "Massima": "High", "Minima": "Low", "Pioggia": "Rain",
  "Sereno": "Clear", "Poco nuvoloso": "Partly cloudy", "Nuvoloso": "Cloudy", "Nebbia": "Fog", "Pioviggine": "Drizzle", "Neve": "Snow", "Temporale": "Thunderstorm", "Variabile": "Changeable",
  "Fa freddo: serve il cappotto.": "It is cold: you need a coat.", "È fresco: porta una giacca.": "It is cool: take a jacket.",
  "Temperatura mite.": "Mild weather.", "Fa caldo: vestiti leggeri.": "It is hot: light clothes.", "Può piovere: prendi l'ombrello.": "It may rain: take an umbrella.",
  "Meteo non disponibile: riprova tra poco.": "Weather not available: try again shortly.", "Posizione non valida.": "Invalid position.", "Date non valide.": "Invalid dates.",
  "Chiedi cosa mettere, cosa sta bene insieme, cosa manca.": "Ask what to wear, what goes together, what is missing.",
  "Lo stylist ha bisogno dell'IA": "The stylist needs the AI", "Scegli l'indirizzo di Ollama e un modello nelle impostazioni del sito.": "Choose the Ollama address and a model in the site settings.",
  "Imposta l'IA": "Set up the AI", "Scrivi allo stylist…": "Write to the stylist…", "Invia": "Send", "Lo stylist ci pensa…": "The stylist is thinking…",
  "Conosce i tuoi capi, il meteo di oggi e cosa hai messo di recente.": "It knows your pieces, today's weather and what you wore lately.", "Nuova conversazione": "New conversation",
  "Cosa mi metto oggi?": "What do I wear today?", "Cosa sta bene con i jeans?": "What goes with jeans?", "Cosa manca nel mio armadio?": "What is missing in my closet?", "Un outfit per una cena elegante": "An outfit for a smart dinner",
  "I capi da portare in viaggio, scelti dal tuo armadio.": "The pieces to take on a trip, chosen from your closet.", "Prepara la valigia": "Pack your suitcase",
  "Dimmi dove vai, quando e per quanto: guardo il meteo del posto e scelgo i capi dal tuo armadio. Poi li spunti mentre li metti in valigia.": "Tell me where you go, when and for how long: I look at the weather there and choose the pieces from your closet. Then you tick them as they go in.",
  "Nuova valigia": "New suitcase", "Dove vai": "Where to", "Cambia": "Change", "Partenza": "Leaving on", "Notti": "Nights", "1 notte": "1 night", "notti": "nights",
  "Il meteo si conosce per i prossimi 16 giorni: per un viaggio più lontano la valigia si fa senza.": "The weather is known for the next 16 days: for a trip further away the suitcase is made without it.",
  "Per cosa": "What for", "Prepara": "Pack", "Sono già tutti in valigia.": "They are all in the suitcase already.",
  "Meteo non ancora disponibile: la valigia è fatta per un tempo mite.": "No forecast yet: the suitcase is made for mild weather.",
  "In valigia": "Packed", "Togli": "Remove", "Ne servirebbero": "You would need", "nell'armadio non ce ne sono abbastanza.": "there are not enough in the closet.",
  "Non dimenticare": "Do not forget", "Biancheria e calze:": "Underwear and socks:", "Pigiama": "Pyjamas", "Caricabatterie e documenti": "Chargers and documents",
  "Ombrello: è prevista pioggia": "Umbrella: rain is forecast", "Occhiali da sole e crema solare": "Sunglasses and sunscreen", "Sciarpa, guanti e berretto": "Scarf, gloves and hat",
  "Calze e borraccia per lo sport": "Sports socks and a water bottle", "Un sacchetto per i panni sporchi: oltre una settimana conviene un lavaggio": "A bag for dirty clothes: over a week, a wash is worth it",
  "Consigli dell'IA": "Tips from the AI", "Con l'IA accesa ti dà qualche consiglio su cosa aggiungere.": "With the AI on, it gives you a few tips on what to add.",
  "Chiedi consigli all'IA": "Ask the AI for tips", "Altri consigli": "More tips",
  "capi messi abbastanza volte dall'ultimo lavaggio": "pieces worn enough times since their last wash", "I capi messi abbastanza volte dall'ultimo lavaggio.": "The pieces worn enough times since their last wash.",
  "Li ho lavati tutti": "I washed them all", "Lavato": "Washed", "dall'ultimo lavaggio": "since the last wash", "Niente da lavare": "Nothing to wash",
  "Quando segni nel diario cosa indossi, i capi messi abbastanza volte finiscono qui. Le volte si cambiano nella scheda di ogni capo.": "When you note in the diary what you wear, the pieces worn enough times end up here. The number of times is changed on each piece.",
  "Magliette e vestiti dopo 2 volte, pantaloni dopo 4, giacche dopo 12. Scarpe, borse e accessori non si contano.": "Tops and dresses after 2 wears, trousers after 4, jackets after 12. Shoes, bags and accessories are not counted.",
  "Primavera": "Spring", "Estate": "Summer", "Autunno": "Autumn", "Inverno": "Winter", "Ora è": "It is now",
  "I capi messi via non compaiono nelle idee del giorno. Le stagioni di un capo si scelgono nella sua scheda; senza, conta quanto è pesante.": "Pieces put away do not show in the ideas of the day. The seasons of a piece are chosen on the piece; without them, how warm it is counts.",
  "L'armadio è già di stagione": "The closet is in season already", "Niente da mettere via o da tirare fuori adesso.": "Nothing to put away or bring out now.",
  "Da tirare fuori": "To bring out", "Da mettere via": "To put away", "Messi via": "Put away", "Tira fuori": "Bring out", "Metti via": "Put away",
  "I capi che non metti da tanto: tienili, mettili via o lasciali andare.": "The pieces you have not worn for long: keep them, put them away or let them go.",
  "3 mesi": "3 months", "6 mesi": "6 months", "1 anno": "1 year", "2 anni": "2 years",
  "I capi che non hai messo in questo tempo (o mai, se sono nell'armadio da così tanto). «Lo tengo» li toglie da qui per sei mesi.": "The pieces you have not worn in this time (or ever, if they have been in the closet that long). \"I keep it\" takes them off this list for six months.",
  "Da decidere": "To decide", "Lo tengo": "I keep it", "Via": "Let go", "Ultima volta": "Last time", "in tutto": "in all", "Mai messo, nell'armadio dal": "Never worn, in the closet since",
  "Niente da sistemare": "Nothing to sort out", "Ogni capo è stato messo di recente. Il diario serve proprio a questo: segna cosa indossi.": "Every piece was worn lately. That is what the diary is for: note what you wear.",
  "Tessuto": "Fabric", "Per esempio cotone, lana": "For example cotton, wool", "Fantasia": "Pattern", "Tinta unita, righe, quadri…": "Plain, stripes, checks…",
  "Stile": "Style", "Casual, elegante, sportivo…": "Casual, smart, sporty…", "Quanto è elegante": "How dressed up", "Casual": "Casual", "Curato": "Smart", "Elegante": "Formal", "Sportivo": "Sporty",
  "Stagioni": "Seasons", "Nessuna scelta: conta quanto è pesante.": "None chosen: how warm it is counts.",
  "Facoltativo, per il costo per uso.": "Optional, for the cost per wear.", "Da lavare dopo": "Wash after",
  "Quante volte lo metti tra un lavaggio e l'altro. Vuoto: il solito per il suo tipo; 0: non si conta.": "How many times you wear it between two washes. Empty: the usual for its kind; 0: not counted.",
  "Messo via": "Put away", "Fuori stagione: non compare nelle idee del giorno.": "Out of season: it does not show in the ideas of the day.",
  "Le volte tra due lavaggi sono un numero intero.": "The wears between two washes are a whole number.",
  "Il prezzo diviso per le volte che l'hai messo. Il prezzo si scrive nella scheda del capo.": "The price divided by the times you wore it. The price is written on the piece.",
  "Spesa per mese": "Spending by month", "Il prezzo di ogni capo, nel mese in cui è entrato nell'armadio.": "The price of each piece, in the month it came into the closet.",
  "Negli ultimi 12 mesi": "In the last 12 months", "Mai messi dopo 60 giorni": "Never worn after 60 days",
  "Nell'armadio da più di due mesi e ancora mai indossati.": "In the closet for more than two months and still never worn.",
  "Soldi fermi nell'armadio": "Money sitting in the closet", "Nell'armadio dal": "In the closet since", "e altri": "and another",
  "Il tuo": "Your", "L'anno in un'immagine, da tenere o da mandare a chi vuoi.": "The year in a picture, to keep or to send to whoever you like.",
  "Scarica l'immagine": "Download the picture", "Condividi": "Share", "giorni nel diario": "days in the diary", "capi messi su": "pieces worn out of",
  "il più messo": "worn the most", "l'outfit dell'anno": "the outfit of the year", "capi nuovi": "new pieces", "Capi nuovi": "New pieces", "Spesi": "Spent",
  "Volte l'outfit più messo": "Wears of the top outfit", "L'outfit dell'anno": "The outfit of the year", "Il più ripagato": "Best value", "a uso": "a wear",
  "Aspetto": "Look", "I colori del sito, in questo browser.": "The colors of the site, in this browser.",
  "Power": "Power", "Ombra": "Shadow", "Bosco": "Forest", "Oceano": "Ocean", "Carta": "Paper",
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

/** What this browser keeps for itself (the town, the suitcase): read, or the fallback. */
function kept(key, fallback = null) {
  try {
    const text = localStorage.getItem(key);
    return text ? JSON.parse(text) : fallback;
  } catch {
    return fallback;
  }
}

function keep(key, value) {
  try {
    if (value === null || value === undefined) localStorage.removeItem(key);
    else localStorage.setItem(key, JSON.stringify(value));
  } catch { /* private window: for this page only */ }
}

const state = {
  status: null, items: [], outfits: [], wears: [], wishes: [], photos: new Set(), period: 'all',
  tab: localStorage.getItem('sw-tab') || 'today',
  category: null, query: '', favorites: false, occasion: null,
  month: monthStart(new Date()), day: dayKey(new Date()),
  user: '', menu: false,
  // Today: the town and its weather, and which idea is shown.
  place: kept('sw-place'), forecast: null, weatherError: '', idea: 0,
  // The stylist's conversation, until the page is closed.
  chat: [], draft: '', thinking: false, chatError: '',
  // The suitcase (one trip, in this browser), the clear-out and the year looked back on.
  trip: kept('sw-trip'), tipsBusy: false, tipsError: '', months: 6, year: null,
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
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2.5V5M12 19v2.5M2.5 12H5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M5.3 18.7l1.8-1.8M16.9 7.1l1.8-1.8"/>',
  cloud: '<path d="M7 18.5h10a4 4 0 0 0 .5-7.97A6 6 0 0 0 6.1 9.6 4.5 4.5 0 0 0 7 18.5Z"/>',
  cloudsun: '<path d="M8 4.2V3M3.8 8.4H2.6M4.9 5.3l-.9-.9M11.1 5.3l.9-.9"/><path d="M5.3 9.6A3 3 0 0 1 10.7 7.3"/><path d="M8.5 19.5h8.7a3.5 3.5 0 0 0 .4-6.98 5.2 5.2 0 0 0-9.9-.82 3.9 3.9 0 0 0 .8 7.8Z"/>',
  rain: '<path d="M7 15h10a4 4 0 0 0 .5-7.97A6 6 0 0 0 6.1 6.1 4.5 4.5 0 0 0 7 15Z"/><path d="m8.5 18-1 2.8M12.5 18l-1 2.8M16.5 18l-1 2.8"/>',
  snow: '<path d="M7 15h10a4 4 0 0 0 .5-7.97A6 6 0 0 0 6.1 6.1 4.5 4.5 0 0 0 7 15Z"/><path d="M8 18.5h.01M12 18.5h.01M16 18.5h.01M10 21.3h.01M14 21.3h.01"/>',
  bolt: '<path d="M7 15h10a4 4 0 0 0 .5-7.97A6 6 0 0 0 6.1 6.1 4.5 4.5 0 0 0 7 15Z"/><path d="m12.8 16-2.3 3h3l-2.3 3"/>',
  pin: '<path d="M12 21s6.5-5.8 6.5-11a6.5 6.5 0 0 0-13 0c0 5.2 6.5 11 6.5 11Z"/><circle cx="12" cy="10" r="2.3"/>',
  chat: '<path d="M4 5.5h16V16H9.5L5 20v-4H4Z"/>',
  suitcase: '<rect x="3.5" y="7.5" width="17" height="12.5" rx="2"/><path d="M9 7.5V5a1.5 1.5 0 0 1 1.5-1.5h3A1.5 1.5 0 0 1 15 5v2.5M3.5 13h17"/>',
  drop: '<path d="M12 3.5c3 3.6 5.5 6.6 5.5 10a5.5 5.5 0 0 1-11 0c0-3.4 2.5-6.4 5.5-10Z"/>',
  leaf: '<path d="M5 19c0-8 5-13.5 15-14-.5 10-6 15-14 15"/><path d="M5 19.5 13 11"/>',
  box: '<rect x="3.5" y="4.5" width="17" height="4.5" rx="1"/><path d="M5 9v9.5A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5V9M10 13h4"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  x: '<path d="M6 6l12 12M18 6 6 18"/>',
  up: '<path d="M12 19V5M6 11l6-6 6 6"/>',
  download: '<path d="M12 4v11M7 10.5l5 5 5-5M5 20h14"/>',
  palette: '<path d="M12 3.5a8.5 8.5 0 1 0 0 17c1.4 0 2-1 2-2 0-1.7 1-2.5 2.5-2.5H18a2.5 2.5 0 0 0 2.5-2.5c0-5.5-3.8-10-8.5-10Z"/><circle cx="8" cy="11" r="1"/><circle cx="11.5" cy="7.5" r="1"/><circle cx="16" cy="9.5" r="1"/>',
  like: '<path d="M7 10.5V20H4.5v-9.5ZM7 11l4-7.5c1.4 0 2.5 1.1 2.5 2.5v3.5h4.3a2 2 0 0 1 2 2.4l-1.2 6.5a2 2 0 0 1-2 1.6H7"/>',
  dislike: '<g transform="rotate(180 12 12)"><path d="M7 10.5V20H4.5v-9.5ZM7 11l4-7.5c1.4 0 2.5 1.1 2.5 2.5v3.5h4.3a2 2 0 0 1 2 2.4l-1.2 6.5a2 2 0 0 1-2 1.6H7"/></g>',
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
  const views = {
    today: todayView, closet: closetView, outfits: outfitsView, diary: diaryView,
    stylist: stylistView, packing: packingView, laundry: laundryView, season: seasonView, clearout: clearOutView,
    wishes: wishlistView, stats: statsView, settings: settingsView,
  };
  const toWash = laundry(state.items, state.wears).length;
  const item = ([key, label, symbol, count]) => h('button', {
    class: `nav-item ${state.tab === key ? 'on' : ''}`, 'aria-current': state.tab === key ? 'page' : null, onclick: () => go(key),
  }, icon(symbol), h('span', { class: 'grow' }, t(label)), count ? h('span', { class: 'n' }, count) : null);
  const logout = async () => { await api('POST', 'logout'); location.reload(); };
  app.replaceChildren(
    h('div', { class: `shell ${state.menu ? 'open' : ''}` },
      h('aside', { class: 'sidebar' },
        h('div', { class: 'brand' }, h('img', { src: 'icon.png', alt: '' }), 'ShadowWear'),
        h('nav', { class: 'nav-list' }, [['today', 'Oggi', 'sun'], ['closet', 'Armadio', 'shirt'], ['outfits', 'Outfit', 'grid'], ['diary', 'Diario', 'calendar']].map(item)),
        h('div', { class: 'nav-label' }, t('Strumenti')),
        h('nav', { class: 'nav-list', style: 'margin-top:0' }, [['stylist', 'Stylist', 'chat'], ['packing', 'Valigia', 'suitcase'], ['laundry', 'Da lavare', 'drop', toWash],
          ['season', 'Cambio di stagione', 'leaf'], ['clearout', 'Pulizia dell\'armadio', 'box'], ['wishes', 'Cosa comprare', 'cart'], ['stats', 'Statistiche', 'chart']].map(item)),
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
        h('main', {}, (views[state.tab] ?? todayView)()))));
}

/** Opens a page of the site. */
function go(key) {
  state.tab = key;
  state.menu = false;
  localStorage.setItem('sw-tab', key);
  render();
  window.scrollTo(0, 0);
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
  const fields = [item.name, item.brand, item.size, item.notes, item.material, item.pattern, item.style, t(CATEGORY[item.category]?.label ?? ''),
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
  let priceText = typeof item.price === 'number' ? moneyText(item.price) : '';
  let washText = typeof item.washEvery === 'number' ? String(item.washEvery) : '';
  const usual = { top: 2, dress: 2, bottom: 4, outerwear: 12 };

  const draw = () => {
    const days = wornDays(item.id);
    const price = h('input', { type: 'text', inputmode: 'decimal', placeholder: '49,90', value: priceText });
    price.addEventListener('input', () => { priceText = price.value; });
    const wash = h('input', { type: 'number', min: '0', max: '99', placeholder: usual[item.category] ? String(usual[item.category]) : '—', value: washText });
    wash.addEventListener('input', () => { washText = wash.value; });
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
      h('div', { class: 'two' },
        field(t('Tessuto'), input(item, 'material', t('Per esempio cotone, lana'))),
        field(t('Fantasia'), input(item, 'pattern', t('Tinta unita, righe, quadri…')))),
      field(t('Stile'), input(item, 'style', t('Casual, elegante, sportivo…'))),
      field(t('Quanto è elegante'), h('div', { class: 'segmented' }, FORMALITY.map(([value, label]) => h('button', {
        type: 'button', class: (item.formality ?? null) === value ? 'on' : '',
        onclick: () => { if (value === null) delete item.formality; else item.formality = value; draw(); },
      }, t(label))))),
      field(t('Stagioni'), h('div', { class: 'chips wrap' }, SEASONS.map((season) => h('button', {
        type: 'button', class: `chip ${(item.seasons ?? []).includes(season) ? 'on' : ''}`,
        onclick: () => {
          const chosen = item.seasons ?? [];
          item.seasons = chosen.includes(season) ? chosen.filter((s) => s !== season) : SEASONS.filter((s) => s === season || chosen.includes(s));
          draw();
        },
      }, t(SEASON_LABEL[season])))), h('span', { class: 'sub small' }, t('Nessuna scelta: conta quanto è pesante.'))),
      h('div', { class: 'two' },
        field(t('Prezzo'), price, h('span', { class: 'sub small' }, t('Facoltativo, per il costo per uso.'))),
        field(t('Da lavare dopo'), wash, h('span', { class: 'sub small' }, t('Quante volte lo metti tra un lavaggio e l\'altro. Vuoto: il solito per il suo tipo; 0: non si conta.')))),
      field(t('Note'), (() => { const a = h('textarea', {}); a.value = item.notes ?? ''; a.oninput = () => { item.notes = a.value; }; return a; })()),
      h('label', { class: 'row' }, h('input', { type: 'checkbox', checked: Boolean(item.favorite), onchange: (e) => { item.favorite = e.target.checked; } }), '★ ', t('Preferito')),
      h('label', { class: 'row' }, h('input', { type: 'checkbox', checked: Boolean(item.stored), onchange: (e) => { item.stored = e.target.checked; } }),
        h('span', {}, t('Messo via'), h('span', { class: 'sub small' }, ` · ${t('Fuori stagione: non compare nelle idee del giorno.')}`))),
      h('div', { class: 'info' }, h('span', {}, t('Messo')), h('span', {}, `${days.length} ${t('volte')}`)),
      h('div', { class: 'info' }, h('span', {}, t('L\'ultima volta')), h('span', {}, days[0] ? fmt(fromKey(days[0]), { day: 'numeric', month: 'long', year: 'numeric' }) : t('mai'))),
      h('div', { class: 'bar' },
        state.status.ai?.available ? h('button', { class: 'btn', onclick: () => describeItem(item, busy, draw) }, '✦ ', t('Descrivi con l\'IA')) : null,
        busy,
        h('div', { class: 'grow' }),
        h('button', { class: 'btn danger', onclick: () => deleteItem(item.id) }, t('Elimina'))));
  };
  draw();
  const save = () => {
    if (!priceText.trim()) delete item.price;
    else {
      const value = parseMoney(priceText);
      if (value === null) return toast(t('Il prezzo non è un numero.'), 4000);
      item.price = value;
    }
    if (!washText.trim()) delete item.washEvery;
    else {
      const every = Number(washText);
      if (!Number.isInteger(every) || every < 0 || every > 99) return toast(t('Le volte tra due lavaggi sono un numero intero.'), 4000);
      item.washEvery = every;
    }
    return saveItem(item);
  };
  dialog(t('Modifica capo'), body, [
    h('button', { class: 'btn', onclick: closeDialog }, t('Annulla')),
    h('button', { class: 'btn primary', onclick: save }, t('Salva')),
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
  if (answer.material && !item.material) item.material = answer.material;
  if (answer.style && !item.style) item.style = answer.style;
  if (answer.notes && !item.notes) item.notes = answer.notes;
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

function openOutfit(id, pieces = []) {
  const existing = id ? state.outfits.find((o) => o.id === id) : null;
  const now = isoNow();
  const outfit = existing ? structuredClone(existing) : { id: uuid(), name: '', items: [...pieces], favorite: false, notes: '', created: now, updated: now };
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
          entries.length ? entries.map(wearRow) : h('span', { class: 'sub' }, t('Niente annotato per questo giorno.')),
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

// ---------- small things the new pages share ----------

/** A piece in a list: its picture, its name, a line under it and what goes on the right. */
function pieceLine(item, detail, ...right) {
  return h('div', { class: 'piece-line' },
    h('button', { class: 'piece-row', onclick: () => openItem(item.id) },
      h('div', { class: 'thumb' }, cover(item)),
      h('div', { class: 'grow' }, h('div', { class: 'name' }, displayName(item)), detail ? h('div', { class: 'sub small' }, detail) : null)),
    right);
}

/** Changes some fields of some pieces (washed, put away, kept) and draws the page again. */
async function changeItems(ids, change) {
  try {
    for (const id of ids) {
      const item = itemByID(id);
      if (item) await api('PUT', `items/${item.id}`, { ...item, ...change });
    }
  } catch (error) {
    toast(error.message, 5000);
  }
  await load();
  render();
}

// ---------- weather ----------

/** The WMO weather code as an icon and a few words. */
function sky(code) {
  if (code === 0) return ['sun', 'Sereno'];
  if (code === 1 || code === 2) return ['cloudsun', 'Poco nuvoloso'];
  if (code === 3) return ['cloud', 'Nuvoloso'];
  if (code === 45 || code === 48) return ['cloud', 'Nebbia'];
  if (code >= 51 && code <= 57) return ['rain', 'Pioviggine'];
  if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return ['rain', 'Pioggia'];
  if ((code >= 71 && code <= 77) || code === 85 || code === 86) return ['snow', 'Neve'];
  if (code >= 95 && code <= 99) return ['bolt', 'Temporale'];
  return ['cloud', 'Variabile'];
}

/** The forecast asked in the last hours: it is for the day at the town chosen, which around
 * midnight may not be the day here. */
function currentForecast() {
  const f = state.forecast;
  return f && Date.now() - f.fetched < 6 * 3_600_000 ? f : null;
}

/** Today's conditions, when the weather is known. */
function todayConditions() {
  const f = currentForecast();
  return f ? { high: f.high, low: f.low, rain: f.rain } : null;
}

function weatherTip(conditions) {
  if (!conditions) return null;
  const parts = [t({ cold: 'Fa freddo: serve il cappotto.', cool: 'È fresco: porta una giacca.', mild: 'Temperatura mite.', hot: 'Fa caldo: vestiti leggeri.' }[band(conditions)])];
  if (rainy(conditions)) parts.push(t('Può piovere: prendi l\'ombrello.'));
  return parts.join(' ');
}

/** Today's weather of the town chosen, asked at most every half hour (and after a failure, a minute later). */
async function refreshWeather(force = false) {
  const place = state.place;
  if (!place || refreshWeather.busy) return;
  const fresh = state.forecast && Date.now() - state.forecast.fetched < 30 * 60_000;
  if (!force && (fresh || Date.now() - (refreshWeather.tried ?? 0) < 60_000)) return;
  refreshWeather.busy = true;
  refreshWeather.tried = Date.now();
  try {
    const forecast = await api('GET', `weather/today?lat=${place.latitude}&lon=${place.longitude}`);
    state.forecast = { ...forecast, fetched: Date.now() };
    state.weatherError = '';
  } catch (error) {
    state.weatherError = error.message;
  } finally {
    refreshWeather.busy = false;
  }
  if (state.tab === 'today') render();
}

/** The towns matching what is typed, to pick one. */
function placeSearch(onPick) {
  const input = h('input', { type: 'search', placeholder: t('Per esempio Lisbona'), autocomplete: 'off' });
  const list = h('div', { class: 'places' });
  let timer = null;
  let asked = 0;
  const search = async () => {
    asked += 1;
    const mine = asked;
    const name = input.value.trim();
    if (name.length < 2) return list.replaceChildren();
    try {
      const { places } = await api('GET', `weather/places?name=${encodeURIComponent(name)}&lang=${IT ? 'it' : 'en'}`);
      if (mine !== asked) return;
      list.replaceChildren(...(places.length
        ? places.map((place) => h('button', { type: 'button', class: 'place', onclick: () => onPick(place) }, icon('pin', 'sm'), place.name))
        : [h('span', { class: 'sub small' }, t('Nessuna città con questo nome.'))]));
    } catch (error) {
      if (mine === asked) list.replaceChildren(h('span', { class: 'error' }, error.message));
    }
  };
  input.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(search, 350); });
  return h('div', { class: 'place-search' }, input, list);
}

function chooseHome() {
  dialog(t('La tua città'), h('div', { class: 'stack' },
    placeSearch((place) => {
      state.place = place;
      keep('sw-place', place);
      state.forecast = null;
      closeDialog();
      render();
      refreshWeather(true);
    }),
    h('p', { class: 'sub small' }, t('Il meteo arriva da Open-Meteo: il server gli manda solo il nome che cerchi e la posizione della città. La città resta in questo browser.'))),
  [h('button', { class: 'btn', onclick: closeDialog }, t('Chiudi'))]);
  document.querySelector('#dialog input')?.focus();
}

function weatherCard() {
  const place = state.place;
  const forecast = currentForecast();
  const town = (label) => h('div', {}, h('button', { class: 'btn small', onclick: chooseHome }, icon('pin', 'sm'), label));
  if (!place) return section('sun', t('Meteo'), t('Scegli la tua città: le idee del giorno tengono conto del tempo che fa.'), town(t('Scegli la città')));
  if (!forecast) {
    return section('sun', t('Meteo'), state.weatherError || t('Carico il meteo…'), town(place.name));
  }
  const [symbol, words] = sky(forecast.code);
  const measure = (label, value) => h('div', { class: 'measure' }, h('div', { class: 'sub small' }, t(label)), h('strong', {}, value));
  return h('section', { class: `section weather ${band(forecast)}` },
    h('div', { class: 'row' },
      h('div', { class: 'grow' }, h('div', { class: 'temp' }, `${Math.round(forecast.now ?? forecast.high)}°`), h('div', {}, t(words))),
      icon(symbol, 'sky')),
    h('div', { class: 'measures' }, measure('Massima', `${Math.round(forecast.high)}°`), measure('Minima', `${Math.round(forecast.low)}°`), measure('Pioggia', `${forecast.rain}%`)),
    town(place.name));
}

// ---------- today ----------

/** A day of the diary: what was worn, how it went (liked or not) and the cross to take it out. */
function wearRow(entry) {
  const pieces = piecesOf(entry.items);
  const outfit = entry.outfit ? state.outfits.find((o) => up(o.id) === up(entry.outfit)) : null;
  const thumb = (rating, symbol, label) => h('button', {
    class: `icon-btn small ${entry.rating === rating ? 'on' : ''}`, title: t(label), 'aria-label': t(label), 'aria-pressed': String(entry.rating === rating),
    onclick: () => rate(entry, entry.rating === rating ? null : rating),
  }, icon(symbol, 'sm'));
  return h('div', { class: 'row wear-row' },
    h('div', { class: 'thumb' }, collage(pieces)),
    h('div', { class: 'grow' }, h('strong', {}, outfit ? outfitName(outfit) : t('Capi scelti')),
      h('div', { class: 'sub small' }, pieces.map(displayName).join(', '))),
    thumb(1, 'like', 'Mi è piaciuto'), thumb(-1, 'dislike', 'Non mi è piaciuto'),
    h('button', { class: 'icon-btn small', title: t('Togli dal diario'), 'aria-label': t('Togli dal diario'), onclick: async () => { await api('DELETE', `wears/${entry.id}`); await load(); render(); } }, icon('x', 'sm')));
}

/** Liked or not liked. Diary entries never change on the server, so the entry is replaced by a new
 * one with the same day and pieces (as the app does). */
async function rate(entry, rating) {
  const next = { id: uuid(), day: entry.day, items: [...(entry.items ?? [])] };
  if (entry.outfit) next.outfit = entry.outfit;
  if (rating) next.rating = rating;
  try {
    await api('PUT', `wears/${next.id}`, next);
    await api('DELETE', `wears/${entry.id}`);
  } catch (error) {
    toast(error.message, 5000);
  }
  await load();
  render();
}

function todayView() {
  const now = new Date();
  const today = dayKey(now);
  refreshWeather();
  const ideas = suggestions({ items: state.items, outfits: state.outfits, wears: state.wears, conditions: todayConditions(), today: now, seed: seedFor(today) });
  const worn = state.wears.filter((w) => w.day === today);
  const toWash = laundry(state.items, state.wears).length;
  return h('div', {},
    pageHead(fmt(now, { weekday: 'long', day: 'numeric', month: 'long' }), t('Un\'idea di cosa mettere, con il meteo di oggi.')),
    h('div', { class: 'today' },
      ideaCard(ideas),
      h('div', { class: 'stack' },
        weatherCard(),
        worn.length ? section('calendar', t('Oggi hai messo'), null, worn.map(wearRow)) : null,
        toWash ? section('drop', `${t('Da lavare')}: ${toWash}`, t('Capi messi abbastanza volte dall\'ultimo lavaggio.'),
          h('div', {}, h('button', { class: 'btn small', onclick: () => go('laundry') }, t('Vedi cosa lavare')))) : null)));
}

function ideaCard(ideas) {
  if (!state.items.length) {
    return section('sparkles', t('Idea per oggi'), t('Il tuo armadio è vuoto: aggiungi i capi e qui trovi ogni giorno un\'idea di cosa mettere, col meteo.'),
      h('div', {}, h('button', { class: 'btn primary', onclick: () => go('closet') }, icon('shirt', 'sm'), t('Vai all\'armadio'))));
  }
  if (!ideas.length) {
    return section('sparkles', t('Idea per oggi'), t('Per avere un\'idea al giorno servono almeno una maglia e dei pantaloni, oppure un vestito.'),
      h('div', {}, h('button', { class: 'btn', onclick: () => go('closet') }, icon('plus', 'sm'), t('Aggiungi capi'))));
  }
  const index = state.idea % ideas.length;
  const idea = ideas[index];
  const pieces = piecesOf(idea.items);
  const outfit = idea.outfit ? state.outfits.find((o) => up(o.id) === up(idea.outfit)) : null;
  const tip = weatherTip(todayConditions());
  return h('section', { class: 'section idea' },
    h('div', { class: 'section-head row' },
      h('h3', { class: 'grow' }, icon('sparkles'), t('Idea per oggi')),
      h('span', { class: 'sub small' }, `${index + 1} ${t('di')} ${ideas.length}`)),
    h('div', { class: 'idea-pic' }, collage(pieces)),
    h('div', {},
      h('div', { class: 'idea-name' }, outfit ? outfitName(outfit) : t('Nuova combinazione')),
      h('p', { class: 'sub' }, pieces.map(displayName).join(', ')),
      tip ? h('p', { class: 'sub small' }, tip) : null),
    h('div', { class: 'bar' },
      h('button', { class: 'btn primary', onclick: () => wear(idea.items, idea.outfit) }, icon('check', 'sm'), t('Lo metto oggi')),
      ideas.length > 1 ? h('button', { class: 'btn', onclick: () => { state.idea = (index + 1) % ideas.length; render(); } }, t('Un\'altra idea')) : null,
      outfit ? h('button', { class: 'btn', onclick: () => openOutfit(outfit.id) }, t('Apri l\'outfit'))
        : h('button', { class: 'btn', onclick: () => openOutfit(null, idea.items) }, t('Salva come outfit'))));
}

// ---------- stylist ----------

const STARTERS = ['Cosa mi metto oggi?', 'Cosa sta bene con i jeans?', 'Cosa manca nel mio armadio?', 'Un outfit per una cena elegante'];

/** The pieces the stylist knows, in the order it sees them: not the ones put away. */
function stylistPieces() {
  return state.items.filter((i) => !i.stored).slice(0, 300);
}

/** The pieces as a numbered list, one line each, for the AI. */
function catalogue(items) {
  return items.map((item, index) => {
    const extra = [t(CATEGORY[item.category]?.label ?? ''), (item.colors ?? []).map((c) => t(COLOR[c]?.name ?? '')).filter(Boolean).join('/'),
      t(WARMTH[warmthOf(item) + 1][1]), item.material, item.pattern, item.style, item.brand].filter(Boolean).join(', ');
    return `${index + 1}. ${displayName(item)} (${extra})`;
  }).join('\n');
}

const languageRule = () => (IT ? 'Rispondi sempre in italiano.' : 'Always answer in English.');

async function askStylist(question) {
  const text = question.trim();
  if (!text || state.thinking) return;
  state.chat.push({ me: true, text });
  state.draft = '';
  state.thinking = true;
  state.chatError = '';
  render();
  try {
    const list = stylistPieces();
    const last = lastWorn(state.wears);
    const recent = list.flatMap((item, i) => (last.get(up(item.id)) ? [`${i + 1}: ${last.get(up(item.id))}`] : [])).slice(0, 40);
    const now = todayConditions();
    const system = [
      `You are the personal stylist inside the ShadowWear app. You know the person's closet (the numbered list) and suggest what to wear, what goes with what, what is missing, how to care for the clothes. When you mention a piece of the closet, write its number in square brackets, e.g. [3]. Be concise and practical, no more than about 120 words. ${languageRule()}`,
      'The closet:', catalogue(list),
      now ? `Today: ${Math.round(now.low)}-${Math.round(now.high)} °C, rain ${now.rain}%.` : 'The weather is not known.',
      `Last worn (number: day): ${recent.join(', ')}`,
      `Today is ${dayKey(new Date())}.`,
    ].join('\n');
    const talk = state.chat.slice(-10).map((m) => (m.me ? 'Person: ' : 'Stylist: ') + m.text).join('\n');
    const answer = await api('POST', 'ai/chat', { system, prompt: `${talk}\nStylist:` });
    state.chat.push({ me: false, text: String(answer.text ?? '').trim(), pieces: list.map((i) => i.id) });
  } catch (error) {
    state.chatError = error.message;
  }
  state.thinking = false;
  if (state.tab === 'stylist') render();
}

function stylistView() {
  if (!aiReady()) {
    return h('div', {},
      pageHead(t('Stylist'), t('Chiedi cosa mettere, cosa sta bene insieme, cosa manca.')),
      emptyState('chat', t('Lo stylist ha bisogno dell\'IA'), t('Scegli l\'indirizzo di Ollama e un modello nelle impostazioni del sito.')),
      h('div', { class: 'center' }, h('button', { class: 'btn', onclick: () => go('settings') }, icon('settings', 'sm'), t('Imposta l\'IA'))));
  }
  const input = h('textarea', { rows: '1', placeholder: t('Scrivi allo stylist…'), 'aria-label': t('Scrivi allo stylist…') });
  input.value = state.draft ?? '';
  input.addEventListener('input', () => { state.draft = input.value; });
  input.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); askStylist(input.value); }
  });
  const bubble = (message) => {
    if (message.me) return h('div', { class: 'bubble me' }, h('p', {}, message.text));
    // The numbers are the ones of the list the AI saw when it answered.
    const seen = (message.pieces ?? []).map(itemByID);
    const named = mentioned(message.text, seen);
    return h('div', { class: 'bubble' },
      h('p', {}, readable(message.text, seen, displayName)),
      named.length ? h('div', { class: 'thumbs' }, named.map((item) => h('button', { class: 'thumb', title: displayName(item), onclick: () => openItem(item.id) }, cover(item)))) : null);
  };
  // After the page is drawn: the last message in view, and the cursor where one writes.
  requestAnimationFrame(() => {
    if (state.tab !== 'stylist') return;
    if (state.chat.length) window.scrollTo(0, document.body.scrollHeight);
    if (!state.thinking) input.focus({ preventScroll: true });
  });
  return h('div', { class: 'chat' },
    pageHead(t('Stylist'), t('Conosce i tuoi capi, il meteo di oggi e cosa hai messo di recente.'),
      state.chat.length ? h('button', { class: 'btn', onclick: () => { state.chat = []; state.chatError = ''; render(); } }, t('Nuova conversazione')) : null),
    state.chat.length ? null : h('div', { class: 'chips wrap' }, STARTERS.map((text) => h('button', { class: 'chip', onclick: () => askStylist(t(text)) }, t(text)))),
    h('div', { class: 'talk' }, state.chat.map(bubble),
      state.thinking ? h('div', { class: 'row sub' }, h('span', { class: 'spin' }), t('Lo stylist ci pensa…')) : null,
      state.chatError ? h('div', { class: 'error', role: 'alert' }, state.chatError) : null),
    h('form', { class: 'ask', onsubmit: (event) => { event.preventDefault(); askStylist(input.value); } },
      input,
      h('button', { class: 'icon-btn send', type: 'submit', disabled: state.thinking, 'aria-label': t('Invia'), title: t('Invia') }, icon('up'))));
}

// ---------- the suitcase ----------

const TRIP_OCCASIONS = OCCASIONS.filter(([key]) => key !== 'home');

function saveTrip(trip) {
  state.trip = trip;
  keep('sw-trip', trip);
  render();
}

const nightsText = (n) => (n === 1 ? t('1 notte') : `${n} ${t('notti')}`);

/** Where, when, how long and what for. */
function openTripForm() {
  const trip = { place: null, start: dayKey(addDays(new Date(), 1)), nights: 3, occasions: ['everyday'] };
  const body = h('div', { class: 'stack' });
  const error = h('div', { class: 'error' });
  const make = h('button', { class: 'btn primary' }, t('Prepara'));
  const draw = () => {
    const start = h('input', { type: 'date', value: trip.start, min: dayKey(new Date()) });
    start.addEventListener('change', () => { if (start.value) trip.start = start.value; });
    const nights = h('input', { type: 'number', min: '1', max: '30', value: String(trip.nights) });
    nights.addEventListener('input', () => { trip.nights = Math.max(1, Math.min(30, Math.round(Number(nights.value)) || 1)); });
    make.disabled = !trip.place;
    body.replaceChildren(
      field(t('Dove vai'), trip.place
        ? h('div', { class: 'row' }, h('span', { class: 'grow row', style: 'gap:8px' }, icon('pin', 'sm'), trip.place.name),
          h('button', { type: 'button', class: 'btn small', onclick: () => { trip.place = null; draw(); } }, t('Cambia')))
        : placeSearch((place) => { trip.place = place; draw(); })),
      h('div', { class: 'two' }, field(t('Partenza'), start), field(t('Notti'), nights)),
      h('p', { class: 'sub small' }, t('Il meteo si conosce per i prossimi 16 giorni: per un viaggio più lontano la valigia si fa senza.')),
      field(t('Per cosa'), h('div', { class: 'chips wrap' }, TRIP_OCCASIONS.map(([key, label]) => h('button', {
        type: 'button', class: `chip ${trip.occasions.includes(key) ? 'on' : ''}`,
        onclick: () => { trip.occasions = trip.occasions.includes(key) ? trip.occasions.filter((o) => o !== key) : [...trip.occasions, key]; draw(); },
      }, t(label))))),
      error);
    if (!trip.place) body.querySelector('input')?.focus();
  };
  make.onclick = async () => {
    make.disabled = true;
    try {
      const { place } = trip;
      const forecast = await api('GET', `weather/trip?lat=${place.latitude}&lon=${place.longitude}&start=${trip.start}&days=${trip.nights + 1}&today=${dayKey(new Date())}`);
      trip.days = forecast.days;
    } catch {
      // No forecast: the suitcase is made without it.
      trip.days = [];
    }
    trip.occasions = OCCASIONS.map(([key]) => key).filter((key) => trip.occasions.includes(key));
    trip.chosen = packingPlan(state.items, trip, state.wears, displayName);
    trip.packed = [];
    trip.tips = '';
    closeDialog();
    saveTrip(trip);
  };
  draw();
  dialog(t('Nuova valigia'), body, [h('button', { class: 'btn', onclick: closeDialog }, t('Annulla')), make]);
}

/** The pieces of a kind that are not in the suitcase yet, to add one. */
function addToSuitcase(category) {
  const trip = state.trip;
  const inside = new Set((trip.chosen ?? []).map(up));
  const options = state.items.filter((i) => i.category === category && !inside.has(up(i.id)));
  dialog(t(CATEGORY[category].label), options.length
    ? h('div', { class: 'grid picker' }, options.map((item) => h('button', {
      type: 'button', class: 'card', onclick: () => { closeDialog(); saveTrip({ ...trip, chosen: [...(trip.chosen ?? []), item.id] }); },
    }, h('div', { class: 'pic' }, cover(item)), h('div', { class: 'meta' }, h('div', { class: 'name small' }, displayName(item))))))
    : h('p', { class: 'sub' }, t('Sono già tutti in valigia.')),
  [h('button', { class: 'btn', onclick: closeDialog }, t('Chiudi'))]);
}

async function askPackingTips(lines) {
  const trip = state.trip;
  state.tipsBusy = true;
  state.tipsError = '';
  render();
  try {
    const weather = (trip.days ?? []).map(conditionsOf).filter(Boolean).map((c) => `${Math.round(c.low)}-${Math.round(c.high)} °C rain ${c.rain}%`).join('; ');
    const prompt = [
      `A trip to ${trip.place.name}, ${trip.nights} nights, for: ${(trip.occasions ?? []).map((o) => t(OCCASION[o])).join(', ')}.`,
      `Weather by day: ${weather || 'not known'}.`,
      `The suitcase so far: ${lines.map((l) => `${l.count} × ${t(CATEGORY[l.category].label)}`).join(', ')}.`,
      'Give 3-5 short tips (one line each, starting with "• ") on what to add, leave home or watch out for.',
    ].join('\n');
    const answer = await api('POST', 'ai/chat', { system: `You are a practical travel stylist. ${languageRule()}`, prompt });
    state.tipsBusy = false;
    return saveTrip({ ...state.trip, tips: String(answer.text ?? '').trim() });
  } catch (error) {
    state.tipsError = error.message;
  }
  state.tipsBusy = false;
  render();
}

function packingView() {
  const trip = state.trip;
  if (!trip?.place) {
    return h('div', {},
      pageHead(t('Valigia'), t('I capi da portare in viaggio, scelti dal tuo armadio.')),
      emptyState('suitcase', t('Prepara la valigia'), t('Dimmi dove vai, quando e per quanto: guardo il meteo del posto e scelgo i capi dal tuo armadio. Poi li spunti mentre li metti in valigia.')),
      h('div', { class: 'center' }, h('button', { class: 'btn primary', onclick: openTripForm }, icon('plus', 'sm'), t('Nuova valigia'))));
  }
  const lines = packingLines(state.items, trip);
  const chosen = new Set(lines.flatMap((l) => l.items.map((i) => up(i.id))));
  const packed = new Set((trip.packed ?? []).map(up).filter((id) => chosen.has(id)));
  const toggle = (id) => saveTrip({ ...trip, packed: packed.has(up(id)) ? (trip.packed ?? []).filter((p) => up(p) !== up(id)) : [...(trip.packed ?? []), id] });
  const remove = (id) => saveTrip({ ...trip, chosen: (trip.chosen ?? []).filter((c) => up(c) !== up(id)), packed: (trip.packed ?? []).filter((p) => up(p) !== up(id)) });
  const known = (trip.days ?? []).filter((d) => conditionsOf(d));
  const when = [fmt(fromKey(trip.start), { day: 'numeric', month: 'long', year: 'numeric' }), nightsText(trip.nights), (trip.occasions ?? []).map((o) => t(OCCASION[o])).join(', ')].filter(Boolean).join(' · ');
  return h('div', {},
    pageHead(trip.place.name, when, h('button', { class: 'btn', onclick: openTripForm }, icon('suitcase', 'sm'), t('Nuova valigia'))),
    known.length
      ? h('div', { class: 'forecast' }, known.map((day) => h('div', { class: 'forecast-day' },
        h('span', { class: 'sub small' }, fmt(fromKey(day.day), { weekday: 'short', day: 'numeric' })),
        icon(rainy(day) ? 'rain' : 'sun'),
        h('strong', {}, `${Math.round(day.high)}°/${Math.round(day.low)}°`))))
      : h('p', { class: 'sub' }, t('Meteo non ancora disponibile: la valigia è fatta per un tempo mite.')),
    h('div', { class: 'stats packing' },
      h('div', { class: 'wide' }, section('suitcase', `${t('In valigia')}: ${packed.size} ${t('di')} ${chosen.size}`, null,
        h('div', { class: 'track' }, h('div', { class: 'fill', style: `width:${chosen.size ? packed.size / chosen.size * 100 : 0}%` })))),
      lines.map((line) => h('section', { class: 'section' },
        h('div', { class: 'section-head row' },
          h('h3', { class: 'grow' }, `${t(CATEGORY[line.category].label)} · ${line.items.length}/${line.count}`),
          h('button', { class: 'btn small', onclick: () => addToSuitcase(line.category) }, icon('plus', 'sm'), t('Aggiungi'))),
        line.items.map((item) => {
          const inside = packed.has(up(item.id));
          return h('div', { class: `piece-line ${inside ? 'done' : ''}` },
            h('button', { class: 'piece-row', 'aria-pressed': String(inside), onclick: () => toggle(item.id) },
              h('span', { class: `tickbox ${inside ? 'on' : ''}` }, inside ? icon('check', 'sm') : null),
              h('div', { class: 'thumb' }, cover(item)),
              h('div', { class: 'grow' }, h('div', { class: 'name' }, displayName(item)), inside ? h('div', { class: 'sub small' }, t('In valigia')) : null)),
            h('button', { class: 'icon-btn small', title: t('Togli'), 'aria-label': t('Togli'), onclick: () => remove(item.id) }, icon('x', 'sm')));
        }),
        line.items.length < line.count ? h('p', { class: 'warn small' }, `${t('Ne servirebbero')} ${line.count}: ${t('nell\'armadio non ce ne sono abbastanza.')}`) : null)),
      section('check', t('Non dimenticare'), null, h('ul', { class: 'list' }, packingReminders(trip).map(([text, n]) => h('li', {}, n === undefined ? t(text) : `${t(text)} ${n}`)))),
      section('sparkles', t('Consigli dell\'IA'), aiReady() ? null : t('Con l\'IA accesa ti dà qualche consiglio su cosa aggiungere.'),
        trip.tips ? h('p', { class: 'tips' }, trip.tips) : null,
        aiReady() ? h('div', { class: 'row' },
          h('button', { class: 'btn', disabled: Boolean(state.tipsBusy), onclick: () => askPackingTips(lines) }, state.tipsBusy ? h('span', { class: 'spin' }) : icon('sparkles', 'sm'), t(trip.tips ? 'Altri consigli' : 'Chiedi consigli all\'IA'))) : null,
        state.tipsError ? h('div', { class: 'error' }, state.tipsError) : null)));
}

// ---------- laundry, seasons, clear-out ----------

function laundryView() {
  const list = laundry(state.items, state.wears);
  const washed = (ids) => changeItems(ids, { washed: isoNow() });
  return h('div', {},
    pageHead(t('Da lavare'), list.length ? `${list.length} ${t('capi messi abbastanza volte dall\'ultimo lavaggio')}` : t('I capi messi abbastanza volte dall\'ultimo lavaggio.'),
      list.length > 1 ? h('button', { class: 'btn primary', onclick: () => washed(list.map((e) => e.item.id)) }, icon('check', 'sm'), t('Li ho lavati tutti')) : null),
    list.length
      ? h('div', { class: 'stack' }, section('drop', `${t('Da lavare')}: ${list.length}`, null, list.map((e) => pieceLine(e.item, `${t('Messo')} ${timesText(e.times)} ${t('dall\'ultimo lavaggio')}`,
        h('button', { class: 'btn small', onclick: () => washed([e.item.id]) }, t('Lavato'))))))
      : emptyState('drop', t('Niente da lavare'), t('Quando segni nel diario cosa indossi, i capi messi abbastanza volte finiscono qui. Le volte si cambiano nella scheda di ogni capo.')),
    h('p', { class: 'sub small', style: 'margin-top:16px;max-width:1040px' }, t('Magliette e vestiti dopo 2 volte, pantaloni dopo 4, giacche dopo 12. Scarpe, borse e accessori non si contano.')));
}

const SEASON_LABEL = { spring: 'Primavera', summer: 'Estate', autumn: 'Autunno', winter: 'Inverno' };
const FORMALITY = [[null, '—'], ['casual', 'Casual'], ['smart', 'Curato'], ['formal', 'Elegante'], ['sporty', 'Sportivo']];

function seasonView() {
  const swap = seasonSwap(state.items, new Date(), (state.place?.latitude ?? 1) < 0);
  const seasons = (item) => SEASONS.filter((s) => seasonsOf(item).has(s)).map((s) => t(SEASON_LABEL[s])).join(', ');
  const store = (ids, away) => changeItems(ids, { stored: away });
  const others = state.items.filter((i) => i.stored && !swap.bringOut.includes(i));
  const group = (title, list, away, label) => (list.length ? h('section', { class: 'section' },
    h('div', { class: 'section-head row' }, h('h3', { class: 'grow' }, `${t(title)}: ${list.length}`),
      list.length > 1 ? h('button', { class: 'btn small', onclick: () => store(list.map((i) => i.id), away) }, t('Tutti')) : null),
    list.map((item) => pieceLine(item, seasons(item), h('button', { class: 'btn small', onclick: () => store([item.id], away) }, t(label))))) : null);
  return h('div', {},
    pageHead(t('Cambio di stagione'), `${t('Ora è')} ${t(SEASON_LABEL[swap.season]).toLowerCase()}`),
    h('p', { class: 'sub', style: 'max-width:760px;margin:0 0 18px' }, t('I capi messi via non compaiono nelle idee del giorno. Le stagioni di un capo si scelgono nella sua scheda; senza, conta quanto è pesante.')),
    swap.putAway.length || swap.bringOut.length || others.length ? null
      : emptyState('leaf', t('L\'armadio è già di stagione'), t('Niente da mettere via o da tirare fuori adesso.')),
    h('div', { class: 'stack' },
      group('Da tirare fuori', swap.bringOut, false, 'Tira fuori'),
      group('Da mettere via', swap.putAway, true, 'Metti via'),
      group('Messi via', others, false, 'Tira fuori')));
}

function clearOutView() {
  const list = clearOut(state.items, state.wears, state.months);
  const keepIt = (item) => changeItems([item.id], { keepUntil: new Date(new Date().setMonth(new Date().getMonth() + 6)).toISOString() });
  const detail = (entry) => (entry.lastWorn
    ? `${t('Ultima volta')}: ${fmt(fromKey(entry.lastWorn), { day: 'numeric', month: 'short', year: 'numeric' })} · ${timesText(entry.times)} ${t('in tutto')}`
    : `${t('Mai messo, nell\'armadio dal')} ${fmt(new Date(entry.item.created), { day: 'numeric', month: 'short', year: 'numeric' })}`);
  return h('div', {},
    pageHead(t('Pulizia dell\'armadio'), t('I capi che non metti da tanto: tienili, mettili via o lasciali andare.'),
      h('div', { class: 'segmented' }, [[3, '3 mesi'], [6, '6 mesi'], [12, '1 anno'], [24, '2 anni']].map(([months, label]) => h('button', {
        type: 'button', class: state.months === months ? 'on' : '', onclick: () => { state.months = months; render(); },
      }, t(label))))),
    h('p', { class: 'sub', style: 'max-width:760px;margin:0 0 18px' }, t('I capi che non hai messo in questo tempo (o mai, se sono nell\'armadio da così tanto). «Lo tengo» li toglie da qui per sei mesi.')),
    list.length
      ? h('div', { class: 'stack' }, section('box', `${t('Da decidere')}: ${list.length}`, null, list.map((entry) => pieceLine(entry.item, detail(entry),
        h('button', { class: 'btn small', onclick: () => keepIt(entry.item) }, t('Lo tengo')),
        h('button', { class: 'btn small', onclick: () => changeItems([entry.item.id], { stored: true }) }, t('Metti via')),
        h('button', { class: 'btn small danger', onclick: () => deleteItem(entry.item.id) }, t('Via'))))))
      : emptyState('box', t('Niente da sistemare'), t('Ogni capo è stato messo di recente. Il diario serve proprio a questo: segna cosa indossi.')));
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

/** A price typed by hand (49,90 or 1.249,00) as a number, or null when it is not one. */
function parseMoney(text) {
  const value = Number(String(text).trim().replace(/\s/g, '').replace(/\.(?=\d{3}(\D|$))/g, '').replace(',', '.'));
  return Number.isFinite(value) && value >= 0 ? value : null;
}

/** A price as it is typed: 49,90. */
function moneyText(value) {
  return (Number.isInteger(value) ? String(value) : value.toFixed(2)).replace('.', IT ? ',' : '.');
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
  const price = h('input', { type: 'text', inputmode: 'decimal', placeholder: '49,90', value: typeof wish.price === 'number' ? moneyText(wish.price) : '' });
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
      value = parseMoney(typed);
      if (value === null) {
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
const timesText = (n) => (n === 1 ? t('1 volta') : `${n} ${t('volte')}`);

function statsView() {
  const since = state.period === 'month' ? dayKey(addDays(new Date(), -30))
    : state.period === 'year' ? dayKey(new Date(new Date().setFullYear(new Date().getFullYear() - 1))) : null;
  const s = stats(state.items, state.wears, since, displayName);
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
  const top = Math.max(1, ...s.byCategory.map((c) => c.count));
  const months = spending(state.items, 12);
  const spent = months.reduce((sum, m) => sum + m.total, 0);
  const dearest = Math.max(1, ...months.map((m) => m.total));
  const waiting = idle(state.items, state.wears, 60);
  const day = (iso) => fmt(new Date(iso), { day: 'numeric', month: 'short', year: 'numeric' });
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
      s.mostWorn.length ? section('calendar', t('I più messi'), null, s.mostWorn.map((e) => pieceRow(e.item, timesText(e.times)))) : null,
      s.liked.length ? section('sparkles', t('Ti piacciono di più'), t('Dai giorni con il pollice in su.'), s.liked.map((item) => pieceRow(item, t(CATEGORY[item.category]?.label ?? '')))) : null,
      s.costPerWear.length ? section('cart', t('Costo per uso'), t('Il prezzo diviso per le volte che l\'hai messo. Il prezzo si scrive nella scheda del capo.'),
        h('div', { class: 'info' }, h('span', {}, t('Valore dell\'armadio')), h('strong', {}, money(s.closetValue))),
        s.costPerWear.slice(0, 8).map((e) => pieceRow(e.item, e.times ? `${t('Messo')} ${timesText(e.times)}` : t('Mai messo'),
          h('strong', { class: e.times ? '' : 'warn' }, money(e.cost))))) : null,
      spent > 0 ? h('div', { class: 'wide' }, section('chart', t('Spesa per mese'), t('Il prezzo di ogni capo, nel mese in cui è entrato nell\'armadio.'),
        h('div', { class: 'info' }, h('span', {}, t('Negli ultimi 12 mesi')), h('strong', {}, money(spent))),
        h('div', { class: 'months', role: 'img', 'aria-label': months.filter((m) => m.total).map((m) => `${fmt(fromKey(`${m.month}-01`), { month: 'long', year: 'numeric' })}: ${money(m.total)}`).join(', ') },
          months.map((m) => h('div', { class: 'month-col', title: `${fmt(fromKey(`${m.month}-01`), { month: 'long', year: 'numeric' })}: ${money(m.total)}` },
            h('span', { class: 'amount' }, m.total ? Math.round(m.total) : ''),
            h('div', { class: 'col' }, h('div', { class: 'fill', style: `height:${m.total / dearest * 100}%` })),
            h('span', { class: 'sub' }, fmt(fromKey(`${m.month}-01`), { month: 'short' }).replace('.', ''))))))) : null,
      waiting.items.length ? section('box', t('Mai messi dopo 60 giorni'), t('Nell\'armadio da più di due mesi e ancora mai indossati.'),
        waiting.value > 0 ? h('div', { class: 'info' }, h('span', {}, t('Soldi fermi nell\'armadio')), h('strong', { class: 'warn' }, money(waiting.value))) : null,
        waiting.items.slice(0, 6).map((item) => pieceRow(item, `${t('Nell\'armadio dal')} ${day(item.created)}`,
          typeof item.price === 'number' && item.price > 0 ? h('strong', {}, money(item.price)) : null)),
        waiting.items.length > 6 ? h('span', { class: 'sub small' }, `${t('e altri')} ${waiting.items.length - 6}`) : null) : null,
      s.neverWorn.length ? section('shirt', t('Mai messi'), null, h('div', { class: 'thumbs' }, s.neverWorn.map((item) => h('button', {
        class: 'thumb', title: displayName(item), onclick: () => openItem(item.id),
      }, cover(item))))) : null,
      recapSection()));
}

// ---------- the year, as a picture to share ----------

function recapSection() {
  const years = recapYears(state.wears);
  if (!years.length) return null;
  const year = years.includes(state.year) ? state.year : years[0];
  const recap = yearRecap(state.items, state.outfits, state.wears, year, displayName);
  const canvas = h('canvas', { class: 'recap', width: '1080', height: '1350', role: 'img', 'aria-label': recapText(recap) });
  const name = `shadowwear-${year}.png`;
  const picture = () => new Promise((resolve) => canvas.toBlob(resolve, 'image/png'));
  const download = async () => {
    const link = h('a', { href: URL.createObjectURL(await picture()), download: name });
    link.click();
    setTimeout(() => URL.revokeObjectURL(link.href), 10_000);
  };
  const share = async () => {
    const file = new File([await picture()], name, { type: 'image/png' });
    try { await navigator.share({ files: [file] }); } catch { /* closed without sharing */ }
  };
  const canShare = (() => {
    try { return Boolean(navigator.canShare?.({ files: [new File([''], name, { type: 'image/png' })] })); } catch { return false; }
  })();
  drawRecap(canvas, recap);
  return h('div', { class: 'wide' }, section('sparkles', `${t('Il tuo')} ${year}`, t('L\'anno in un\'immagine, da tenere o da mandare a chi vuoi.'),
    years.length > 1 ? h('div', { class: 'chips' }, years.map((y) => h('button', { class: `chip ${y === year ? 'on' : ''}`, onclick: () => { state.year = y; render(); } }, y))) : null,
    h('div', { class: 'recap-box' }, canvas,
      h('div', { class: 'stack', style: 'gap:10px' },
        h('p', { class: 'sub' }, recapText(recap)),
        h('div', { class: 'row', style: 'flex-wrap:wrap' },
          h('button', { class: 'btn primary', onclick: download }, icon('download', 'sm'), t('Scarica l\'immagine')),
          canShare ? h('button', { class: 'btn', onclick: share }, t('Condividi')) : null)))));
}

/** The year in a sentence, for who cannot see the picture. */
function recapText(recap) {
  const parts = [`${recap.days} ${t('giorni nel diario')}`, `${recap.wornPieces} ${t('capi messi su')} ${recap.pieces}`];
  if (recap.mostWorn[0]) parts.push(`${t('il più messo')}: ${displayName(recap.mostWorn[0].item)} (${timesText(recap.mostWorn[0].times)})`);
  if (recap.topOutfit) parts.push(`${t('l\'outfit dell\'anno')}: ${outfitName(recap.topOutfit.outfit)}`);
  if (recap.added) parts.push(`${recap.added} ${t('capi nuovi')}`);
  return `${recap.year}: ${parts.join(', ')}.`;
}

/** Draws the year on the canvas, in the colors of the look in use. */
async function drawRecap(canvas, recap) {
  const css = getComputedStyle(document.documentElement);
  const color = (name) => css.getPropertyValue(name).trim();
  const [bg, card, text, sub, accent, ink, stageA, stageB] = ['--bg', '--card', '--text', '--sub', '--accent', '--accent-ink', '--stage-a', '--stage-b'].map(color);
  const mono = "ui-monospace, 'SF Mono', 'Cascadia Mono', 'Segoe UI Mono', 'Roboto Mono', Menlo, Consolas, monospace";
  const ctx = canvas.getContext('2d');
  const W = canvas.width;
  const M = 72;
  const face = (size, weight = 600) => { ctx.font = `${weight} ${size}px ${mono}`; };
  const box = (x, y, w, h, r, fill) => { ctx.beginPath(); ctx.roundRect(x, y, w, h, r); ctx.fillStyle = fill; ctx.fill(); };
  /** Text cut with an ellipsis when it is wider than its place. */
  const write = (string, x, y, width, fill) => {
    let shown = String(string);
    if (ctx.measureText(shown).width > width) {
      while (shown.length > 1 && ctx.measureText(`${shown}…`).width > width) shown = shown.slice(0, -1);
      shown = `${shown.trimEnd()}…`;
    }
    ctx.fillStyle = fill;
    ctx.fillText(shown, x, y);
  };
  const photos = await Promise.all(recap.mostWorn.map((e) => new Promise((resolve) => {
    const photo = e.item.photos?.[0];
    if (!photo) return resolve(null);
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => resolve(null);
    image.src = photoURL(photo);
  })));

  ctx.textBaseline = 'alphabetic';
  box(0, 0, W, canvas.height, 0, bg);
  face(30);
  ctx.letterSpacing = '6px';
  write('SHADOWWEAR', M, 118, W - 2 * M, accent);
  ctx.letterSpacing = '-4px';
  face(132);
  write(`${t('Il tuo')} ${recap.year}`.toUpperCase(), M, 258, W - 2 * M, text);
  ctx.letterSpacing = '0px';

  // Four numbers.
  const tiles = [
    [String(recap.days), t('Giorni nel diario')],
    [`${recap.wornPieces}/${recap.pieces}`, t('Capi messi')],
    [String(recap.added), t('Capi nuovi')],
    recap.spent > 0 ? [money(Math.round(recap.spent)).replace(/[.,]00/, ''), t('Spesi')] : [recap.topOutfit ? String(recap.topOutfit.times) : '—', t('Volte l\'outfit più messo')],
  ];
  const tw = (W - 2 * M - 24) / 2;
  tiles.forEach(([value, label], i) => {
    const x = M + (i % 2) * (tw + 24);
    const y = 320 + Math.floor(i / 2) * 184;
    box(x, y, tw, 160, 28, card);
    face(68);
    ctx.letterSpacing = '-2px';
    write(value, x + 30, y + 86, tw - 60, text);
    ctx.letterSpacing = '0px';
    face(26, 500);
    write(label, x + 30, y + 130, tw - 60, sub);
  });

  // The three pieces worn the most, each on its stage.
  let y = 724;
  face(30);
  write(t('I più messi').toUpperCase(), M, y, W - 2 * M, sub);
  y += 24;
  const pw = (W - 2 * M - 48) / 3;
  recap.mostWorn.forEach((entry, i) => {
    const x = M + i * (pw + 24);
    const stage = ctx.createRadialGradient(x + pw / 2, y + 110, 0, x + pw / 2, y + 110, pw * 0.8);
    stage.addColorStop(0, stageA);
    stage.addColorStop(1, stageB);
    box(x, y, pw, 260, 28, stage);
    const image = photos[i];
    if (image) {
      const scale = Math.min((pw - 40) / image.width, 224 / image.height);
      const w = image.width * scale;
      const hgt = image.height * scale;
      ctx.save();
      ctx.beginPath();
      ctx.roundRect(x, y, pw, 260, 28);
      ctx.clip();
      ctx.shadowColor = 'rgba(0, 0, 0, 0.4)';
      ctx.shadowBlur = 18;
      ctx.shadowOffsetY = 10;
      ctx.drawImage(image, x + (pw - w) / 2, y + (260 - hgt) / 2, w, hgt);
      ctx.restore();
    }
    face(26);
    write(displayName(entry.item), x + 4, y + 298, pw - 8, text);
    face(24, 500);
    write(timesText(entry.times), x + 4, y + 330, pw - 8, sub);
  });
  y += recap.mostWorn.length ? 362 : 20;

  // The colors worn, as one bar.
  const total = recap.colors.reduce((sum, c) => sum + c.count, 0);
  if (total) {
    ctx.save();
    ctx.beginPath();
    ctx.roundRect(M, y, W - 2 * M, 28, 14);
    ctx.clip();
    let x = M;
    for (const c of recap.colors) {
      const w = (W - 2 * M) * c.count / total;
      ctx.fillStyle = COLOR[c.key]?.rgb ?? sub;
      ctx.fillRect(x, y, w - 4, 28);
      x += w;
    }
    ctx.restore();
  }

  // The outfit of the year, or the piece that paid for itself best.
  const line = recap.topOutfit ? [t('L\'outfit dell\'anno'), `${outfitName(recap.topOutfit.outfit)} · ${timesText(recap.topOutfit.times)}`]
    : recap.best ? [t('Il più ripagato'), `${displayName(recap.best.item)} · ${money(recap.best.cost)} ${t('a uso')}`] : null;
  if (line) {
    const top = canvas.height - M - 104;
    box(M, top, W - 2 * M, 104, 52, accent);
    face(24, 500);
    write(line[0].toUpperCase(), M + 44, top + 44, W - 2 * M - 88, ink);
    face(32);
    write(line[1], M + 44, top + 82, W - 2 * M - 88, ink);
  }
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
    section('palette', t('Aspetto'), t('I colori del sito, in questo browser.'), themePicker()),
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

const LOOKS = [['power', 'Power', '#262642'], ['ombra', 'Ombra', '#0f0f11'], ['bosco', 'Bosco', '#12211c'], ['oceano', 'Oceano', '#0e2233'], ['carta', 'Carta', '#f1f2f6']];

/** The five looks of the app, each drawn in its own colors; the one chosen stays in this browser. */
function themePicker() {
  const current = document.documentElement.dataset.theme || 'power';
  const choose = (look, page) => {
    document.documentElement.dataset.theme = look;
    try { localStorage.setItem('sw-theme', look); } catch { /* private window: for this page only */ }
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', page);
    document.querySelector('meta[name="color-scheme"]')?.setAttribute('content', look === 'carta' ? 'light' : 'dark');
    render();
  };
  return h('div', { class: 'looks', role: 'radiogroup', 'aria-label': t('Aspetto') }, LOOKS.map(([look, name, page]) => h('button', {
    type: 'button', class: `look ${look === current ? 'on' : ''}`, role: 'radio', 'aria-checked': String(look === current), onclick: () => choose(look, page),
  }, h('span', { class: 'swatch-look', 'data-theme': look }, h('span', { class: 'bar-look' }, h('i', {})), h('span', { class: 'pill-look' })),
  h('span', { class: 'row', style: 'gap:5px;justify-content:center' }, look === current ? icon('check', 'xs') : null, t(name)))));
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
