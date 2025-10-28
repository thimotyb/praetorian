# Praetorian · Guida per Agenti

Questa guida riassume lo stato attuale del progetto e fornisce istruzioni rapide per continuare lo sviluppo con altri agenti o collaboratori.

## Stack & Tooling
- **Linguaggio**: TypeScript (Esm/CJS via ts-node)
- **Librerie principali**:
  - `puppeteer` (scraping dell'Albo Pretorio)
  - `nodemailer` (invio email)
  - `dotenv` (gestione variabili d'ambiente)
- **Build/Test**: `npm run build` (tsc), `npm start` (ts-node)
- **Docker**: `Dockerfile` pronto per la distribuzione headless con Chromium

## File Chiave
- `scraper.ts`: logica principale (scraping, deduplica, invio email, firma dinamica)
- `config.json`: keywords e lista destinatari
- `.env` (da creare): credenziali SMTP e variabili opzionali
- `README.md`: istruzioni dettagliate per setup, Docker, SMTP, test mode
- `env.example`: template delle variabili d'ambiente

## Stato Funzionale
- Scraping funzionante con stepper dinamico: inserisce la keyword nel campo `Oggetto`, forza `Archivio = 'S'`, avanza al secondo step, legge la tabella dei risultati (`#idTabella2`).
- Link email corretti: aggiunta automatica del parametro `DB_NAME=l200130`.
- Firma email brandizzata: versione Praetorian (`PRAETORIAN_VERSION`), immagine pretoriana da Wikimedia e rotazione casuale di 25 motti latini (`SIGN_OFFS`).
- Modalità test email: impostando `PRAETORIAN_TEST_RECIPIENT` si invia a un solo indirizzo (log dedicato).

## Variabili d'Ambiente Principali
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS` — obbligatorie per l'invio via Nodemailer
- `PRAETORIAN_TEST_RECIPIENT` — opzionale: se valorizzata sovrascrive la lista destinatari
- (Opzionale) `APP_PASSWORD` — per salvare la Google App Password in modo esplicito

## Come Eseguire Test in Sicurezza
1. Copia `env.example` in `.env` e riempi i valori SMTP.
2. Per test non invasivi imposta `PRAETORIAN_TEST_RECIPIENT=tuoindirizzo@test`.
3. Esegui `npm start` (invia email) oppure `npm run build` per validare la compilazione.

## Note Operative
- Il file `seen_publications.json` mantiene lo stato ed è ignorato da Git.
- `config.json` è versionato: modifica con attenzione e committa quando cambi destinatari/keywords.
- Il repository è già containerizzato; segui la sezione "Running in Docker" del README per deployment.

## Checklist prima di lasciare il progetto ad un altro agente
- [ ] `.env` aggiornato localmente (ma non committato)
- [ ] `config.json` coerente con i destinatari richiesti
- [ ] `seen_publications.json` opzionalmente resettato (`[]`) per forzare un nuovo invio
- [ ] Test eseguiti (`npm run build` o `npm start` con `PRAETORIAN_TEST_RECIPIENT`)
- [ ] `git status` pulito e push eseguito

Buon lavoro, Pretoriano digitale!
