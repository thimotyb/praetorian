# Praetorian · Agent Handbook

This guide summarises the current state of the project and gives quick instructions so another agent can pick up development seamlessly.

## Stack & Tooling
- **Language**: TypeScript (CommonJS via ts-node)
- **Key libraries**:
  - `puppeteer` for interacting with the Albo Pretorio portal
  - `nodemailer` for outbound email
  - `dotenv` for environment configuration
- **Tasks**: `npm start` (ts-node runtime) · `npm run build` (tsc compilation)
- **Container**: `Dockerfile` builds a headless Chromium image ready for deployment

## Core Files
- `scraper.ts` – end-to-end workflow: scrape → deduplicate → notify → persist state
- `config.json` – keyword watchlist and primary recipient list
- `.env` (local) – SMTP credentials and optional overrides
- `env.example` – template for required variables
- `README.md` – usage, SMTP setup, Docker instructions, testing tips

## Functional Snapshot
- Dynamic stepper automation: fills the `Oggetto` field, forces `Archivio = 'S'`, advances to step 2, parses `#idTabella2` rows.
- Email links automatically append `DB_NAME=l200130` so detail pages open correctly.
- Branded footer: Praetorian version string, Wikimedia image, and 25 rotating Latin mottos (`SIGN_OFFS`).
- Test-mode override: setting `PRAETORIAN_TEST_RECIPIENT` sends mail to a single address (logged accordingly).

## Important Environment Variables
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS` – required for Nodemailer
- `PRAETORIAN_TEST_RECIPIENT` – optional single-recipient override for dry runs
- `APP_PASSWORD` (optional) – convenient place to store the Gmail app password

## Safe Testing Workflow
1. Copy `env.example` to `.env` and fill in SMTP values if you have not already.
2. **Set the test recipient**: add `PRAETORIAN_TEST_RECIPIENT=you@example.com` in `.env` (or prefix the command, e.g. `PRAETORIAN_TEST_RECIPIENT=you@example.com npm start`). This ensures only your inbox receives notifications during test runs.
3. **Reset state if you want to re-send the latest acts**: run `echo "[]" > seen_publications.json` so the scraper treats all hits as new. This file is ignored by Git.
4. Run `npm start` to execute the full workflow (scrape + email). Logs will note when test mode is active. For a quick static check without sending mail, run `npm run build` instead.
5. After testing, remove or clear `PRAETORIAN_TEST_RECIPIENT` to restore normal multi-recipient delivery.

## Operational Notes
- `seen_publications.json` stores state, is Git-ignored, and can be reset to `[]` to force a fresh notification.
- `config.json` is version-controlled; update keywords/recipients intentionally and commit changes.
- Docker usage is documented in the README; mount `.env`, `config.json`, and `seen_publications.json` for persistence.

## Handoff Checklist for the Next Agent
- [ ] `.env` updated locally (never committed)
- [ ] `config.json` reflects the desired recipients/keywords
- [ ] `seen_publications.json` reset if a clean run is needed
- [ ] Tests executed (`npm run build` and/or `npm start` with `PRAETORIAN_TEST_RECIPIENT`)
- [ ] `git status` clean and latest changes pushed

Stay vigilant, digital Praetorian!
