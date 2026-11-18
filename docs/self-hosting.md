# Il tuo server ShadowWear · Your own ShadowWear server

[Italiano](#italiano) · [English](#english)

## Italiano

L'app sull'iPhone funziona anche da sola, senza server. Il server serve per avere **lo stesso armadio su
più dispositivi** (iPhone, iPad, un altro iPhone) e per vederlo dal **computer**, con il sito.

Ogni server ha **un account** e quindi un armadio. Ognuno installa il suo: sulla NAS di casa, su un
Raspberry Pi, su un mini PC o su un server in affitto (VPS). Per più persone nella stessa casa basta
avviarne uno per persona, con porte e cartelle diverse ([esempio](#più-persone-sulla-stessa-macchina)).

### Cosa serve
- Un computer sempre acceso con **Docker**: NAS (TrueNAS, Synology, Unraid, QNAP), Raspberry Pi 4 o 5,
  mini PC, VPS. L'immagine va su Intel/AMD e su ARM.
- Circa 100 MB di RAM, più lo spazio per le foto (pochi MB ogni 10 capi).
- Facoltativo: [Ollama](https://ollama.com) con un modello che vede le foto, per *Descrivi con l'IA*.

### 1. Avviarlo
Con **Docker Compose**: scarica [`server/deploy/docker-compose.yml`](../server/deploy/docker-compose.yml)
in una cartella vuota e, in quella cartella:

```sh
docker compose up -d
```

Oppure con un solo comando:

```sh
docker run -d --name shadowwear --restart unless-stopped -p 8080:8080 -v "$PWD/shadowwear-data:/data" ghcr.io/theblackside243/shadowwear-server:latest
```

**TrueNAS**: Apps → Discover → Custom App → *Install via YAML*, con
[`server/deploy/truenas-app.yaml`](../server/deploy/truenas-app.yaml). Prima crea il dataset per i dati
e scrivi il suo percorso nel file. L'indirizzo sarà `http://<NAS>:30320`.

### 2. Creare l'account
Apri `http://<indirizzo del server>:8080` dal computer o dall'iPhone e scegli **nome utente** e
**password** (almeno 10 caratteri). Lo puoi fare anche dall'app: **Usa un server** al primo avvio, oppure
Impostazioni → Server → *Collega al server*.

Finché non c'è un account, chiunque potrebbe sceglierlo. Per questo il primo account si crea:
- **dalla rete di casa**, senza altro;
- **da internet** (per esempio su un VPS) solo con il **codice di installazione**. Il server lo scrive nel
  suo log al primo avvio:

  ```sh
  docker logs shadowwear
  ```

  Puoi anche sceglierlo tu con la variabile `SETUP_CODE`.

### 3. Collegare gli altri dispositivi
- **iPhone/iPad**: Impostazioni → Server → *Collega al server*, con indirizzo, nome utente e password.
- **Senza scrivere la password**: dal sito, Impostazioni → *Collega un dispositivo*. Il codice vale
  10 minuti e c'è anche il QR, che l'app sa leggere.

### 4. Usarlo fuori casa (HTTPS)
In casa basta l'indirizzo `http://`. Da fuori serve **HTTPS**, cioè un proxy davanti al server:
[Caddy](https://caddyserver.com), Nginx Proxy Manager, Traefik o un tunnel Cloudflare. Le **passkey**
del sito funzionano solo in HTTPS, con un nome fisso (per esempio `armadio.example.org`).

Esempio con Caddy, che prende da solo il certificato:

```
armadio.example.org {
	reverse_proxy shadowwear:8080
}
```

Il server si fida degli header del proxy (`X-Forwarded-For`, `X-Forwarded-Proto`, `CF-Connecting-IP`)
**solo se il proxy è nella rete locale** o nella rete di Docker. Non aprire la porta 8080 direttamente
su internet: passa sempre dal proxy.

Da internet il server rallenta chi sbaglia la password (per indirizzo e per account). I token degli
iPhone scadono dopo 90 giorni senza uso.

### 5. L'IA (facoltativa)
Con un **Ollama** raggiungibile dal server:
1. sul sito, Impostazioni → Intelligenza artificiale, scrivi l'indirizzo (per esempio `http://192.168.1.10:11434`)
   e premi **Prova**;
2. scegli un modello con 👁, cioè uno che vede le foto (per esempio `qwen2.5vl`, `llava`, `gemma3`).

Puoi anche metterlo all'avvio con `OLLAMA_URL`. Senza IA l'app funziona lo stesso: riconosce colore e tipo
direttamente sul telefono.

### 6. Aggiornare
```sh
docker compose pull && docker compose up -d
```

Su TrueNAS: apri l'app e scegli *Update* (o *Pull image*), poi riavviala. I dati restano nella loro cartella.

Le versioni dell'immagine sono:
- `latest`: l'ultima versione;
- `0.5`: l'ultima 0.5.x;
- `0.5.5`: proprio quella versione.

### 7. Backup
Tutto è nella cartella dei dati (`/data` nel container):

| File | Cosa c'è |
|---|---|
| `closet.json` | capi, outfit, diario, cose da comprare |
| `photos/` | le foto (`.jpg` originale, `.png` senza sfondo) |
| `auth.json` | l'account, le passkey e i dispositivi collegati |
| `settings.json` | lingua, Ollama e modello |

Copia la cartella intera, meglio con il server fermo. Non rinominare le foto: i nomi sono quelli
scritti in `closet.json`.

### Variabili

| Variabile | Predefinito | A cosa serve |
|---|---|---|
| `PORT` | `8080` | La porta dentro il container |
| `DATA_DIR` | `/data` | La cartella dei dati |
| `OLLAMA_URL` | vuoto | L'Ollama da usare se sul sito non ne scegli un altro |
| `SETUP_CODE` | casuale, nel log | Il codice per creare il primo account da internet |
| `TZ` | `UTC` | Il fuso orario (le ore scritte nel log) |

### Più persone sulla stessa macchina
Un servizio per persona, ognuno con la sua porta e la sua cartella:

```yaml
services:
  anna:
    image: ghcr.io/theblackside243/shadowwear-server:latest
    ports: ["8081:8080"]
    volumes: ["./anna:/data"]
    restart: unless-stopped
  marco:
    image: ghcr.io/theblackside243/shadowwear-server:latest
    ports: ["8082:8080"]
    volumes: ["./marco:/data"]
    restart: unless-stopped
```

### Senza Docker
Serve Node 20 o più recente; non ci sono dipendenze:

```sh
cd server
DATA_DIR=./data PORT=8080 node src/server.js
```

## English

The iPhone app also works on its own, without a server. The server gives you **the same closet on several
devices** (iPhone, iPad, another iPhone) and a web site for the **computer**.

Each server has **one account**, so one closet. Everyone runs their own: on a NAS at home, a Raspberry
Pi, a mini PC or a rented server (VPS). For more people in the same house, start one per person with
different ports and folders ([example](#more-people-on-the-same-machine)).

### What you need
- A computer that stays on, with **Docker**: a NAS (TrueNAS, Synology, Unraid, QNAP), a Raspberry Pi 4
  or 5, a mini PC, a VPS. The image runs on Intel/AMD and ARM.
- About 100 MB of RAM, plus room for the photos (a few MB every 10 pieces).
- Optional: [Ollama](https://ollama.com) with a model that sees photos, for *Describe with AI*.

### 1. Start it
With **Docker Compose**: download [`server/deploy/docker-compose.yml`](../server/deploy/docker-compose.yml)
into an empty folder and, in that folder:

```sh
docker compose up -d
```

Or with one command:

```sh
docker run -d --name shadowwear --restart unless-stopped -p 8080:8080 -v "$PWD/shadowwear-data:/data" ghcr.io/theblackside243/shadowwear-server:latest
```

**TrueNAS**: Apps → Discover → Custom App → *Install via YAML*, with
[`server/deploy/truenas-app.yaml`](../server/deploy/truenas-app.yaml). Create the dataset for the data
first and write its path in the file. The address will be `http://<NAS>:30320`.

### 2. Create the account
Open `http://<server address>:8080` from the computer or the iPhone and choose a **user name** and a
**password** (at least 10 characters). The app can do it too: **Use a server** on first launch, or
Settings → Server → *Connect to the server*.

While there is no account, anyone could choose it. So the first account is created:
- **from the home network**, with nothing else;
- **from the internet** (on a VPS, for example) only with the **setup code**. The server writes it in its
  log when it first starts:

  ```sh
  docker logs shadowwear
  ```

  You can also choose it yourself with the `SETUP_CODE` variable.

### 3. Connect the other devices
- **iPhone/iPad**: Settings → Server → *Connect to the server*, with the address, user name and password.
- **Without typing the password**: on the site, Settings → *Connect a device*. The code lasts 10 minutes
  and comes with a QR code the app can read.

### 4. Use it away from home (HTTPS)
At home the `http://` address is enough. From outside you need **HTTPS**, so a proxy in front of the
server: [Caddy](https://caddyserver.com), Nginx Proxy Manager, Traefik or a Cloudflare tunnel. The site's
**passkeys** only work over HTTPS, with a fixed name (for example `closet.example.org`).

Example with Caddy, which gets the certificate on its own:

```
closet.example.org {
	reverse_proxy shadowwear:8080
}
```

The server trusts the proxy's headers (`X-Forwarded-For`, `X-Forwarded-Proto`, `CF-Connecting-IP`)
**only when the proxy is on the local network** or on Docker's network. Do not open port 8080 to the
internet directly: always go through the proxy.

From the internet the server slows down wrong passwords (per address and per account). iPhone tokens
expire after 90 days without use.

### 5. AI (optional)
With an **Ollama** the server can reach:
1. on the site, Settings → AI, type its address (for example `http://192.168.1.10:11434`) and press **Try**;
2. choose a model with 👁, one that sees photos (for example `qwen2.5vl`, `llava`, `gemma3`).

It can also be set at start with `OLLAMA_URL`. Without AI the app still works: it recognises color and
kind on the phone.

### 6. Update
```sh
docker compose pull && docker compose up -d
```

On TrueNAS: open the app and choose *Update* (or *Pull image*), then restart it. The data stay in their
folder.

The image versions are:
- `latest`: the newest version;
- `0.5`: the newest 0.5.x;
- `0.5.5`: exactly that version.

### 7. Backup
Everything is in the data folder (`/data` in the container):

| File | What is in it |
|---|---|
| `closet.json` | pieces, outfits, diary, things to buy |
| `photos/` | the photos (`.jpg` original, `.png` without background) |
| `auth.json` | the account, passkeys and connected devices |
| `settings.json` | language, Ollama and model |

Copy the whole folder, best with the server stopped. Do not rename the photos: their names are the ones
written in `closet.json`.

### Variables

| Variable | Default | What it is for |
|---|---|---|
| `PORT` | `8080` | The port inside the container |
| `DATA_DIR` | `/data` | The data folder |
| `OLLAMA_URL` | empty | The Ollama to use when none is chosen on the site |
| `SETUP_CODE` | random, in the log | The code for creating the first account from the internet |
| `TZ` | `UTC` | The time zone (the times in the log) |

### More people on the same machine
One service per person, each with its own port and folder:

```yaml
services:
  anna:
    image: ghcr.io/theblackside243/shadowwear-server:latest
    ports: ["8081:8080"]
    volumes: ["./anna:/data"]
    restart: unless-stopped
  marco:
    image: ghcr.io/theblackside243/shadowwear-server:latest
    ports: ["8082:8080"]
    volumes: ["./marco:/data"]
    restart: unless-stopped
```

### Without Docker
Node 20 or newer; there are no dependencies:

```sh
cd server
DATA_DIR=./data PORT=8080 node src/server.js
```
