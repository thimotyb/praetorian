# Praetorian Scraper

This script monitors the "Albo Pretorio" of Cernusco sul Naviglio for new publications based on a configured set of keywords.

## 1. Setup

First, install the dependencies:

```bash
npm install
```

## 2. Configuration

1.  **Environment Variables**: Create a `.env` file by copying `.env.example` and fill in your credentials.
    ```bash
    cp .env.example .env
    ```
    You will need SMTP credentials to send emails. For Gmail:

    - Abilita l'autenticazione a due fattori sul tuo account Google.
    - Visita <https://myaccount.google.com/apppasswords>, scegli "Mail" come app e "Altro" oppure "Dispositivo per la scrittura di app" come dispositivo.
    - Genera una password a 16 caratteri e incollala in `SMTP_PASS` (e, se vuoi, in `APP_PASSWORD`).

    Durante i test puoi impostare `PRAETORIAN_TEST_RECIPIENT` in `.env` per forzare l'invio verso una sola casella (ad esempio `thimoty@thimoty.it`).

2.  **Keywords & Emails**: The `config.json` file contains the keywords to search for and the email recipients. You can edit this file directly if needed.

## 3. Running the Script

You can run the script manually with the following command:

```bash
npm start
```

For automatic daily execution, you should set up a cron job or a similar scheduler in your cloud environment (e.g., GitHub Actions, Vercel Cron Jobs, AWS Lambda Scheduled Events) to run this command once a day.

## 4. Running in Docker

1. Build the image (run this from the repository root):

   ```bash
   docker build -t praetorian-scraper .
   ```

2. (One time) Create an empty state file on the host so Docker can bind-mount it:

   ```bash
   touch seen_publications.json
   ```

3. Run the container, providing your environment variables and mounting the configuration/state files so they persist on the host:

   ```bash
   docker run --rm \
     --env-file .env \
     -v "$(pwd)/config.json:/app/config.json:ro" \
     -v "$(pwd)/seen_publications.json:/app/seen_publications.json" \
     praetorian-scraper
   ```

   - `--env-file .env` supplies the SMTP credentials.
   - Mounting `config.json` lets you edit keywords/emails without rebuilding the image.
   - Mounting `seen_publications.json` keeps track of what has already been processed across runs.

You can schedule the container (e.g., with `cron`, `systemd`, or your container orchestrator) to execute once per day.

## How it Works

-   **State**: The script creates a `seen_publications.json` file to keep track of publications that have already been reported, ensuring you only get notified about new ones.
-   **Scraping**: It uses Puppeteer to navigate the website, perform searches, and parse the results.
-   **Notifications**: It sends an email digest of all new findings to the configured recipients.
