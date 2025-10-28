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

    - Enable two-factor authentication on your Google account.
    - Visit <https://myaccount.google.com/apppasswords>, choose "Mail" as the app and "Other" (or your device) as the platform.
    - Generate the 16-character password and paste it into `SMTP_PASS` (and optionally `APP_PASSWORD`).

    During tests you can set `PRAETORIAN_TEST_RECIPIENT` in `.env` to route notifications to a single inbox (e.g. `thimoty@thimoty.it`).

2.  **Keywords & Emails**: The `config.json` file contains the keywords to search for and the email recipients. You can edit this file directly if needed.

## 3. Running the Script

You can run the script manually with the following command:

```bash
npm start
```

For automatic daily execution, you can either:

-   Run it in your cloud environment (e.g., GitHub Actions, Vercel Cron Jobs, AWS Lambda Scheduled Events).
-   Or schedule it locally on Windows (WSL2) using Task Scheduler:

    1.  Ensure the repository contains `run-praetorian.sh` (wrapper script). Make it executable: `chmod +x run-praetorian.sh`.
    2.  Open **Task Scheduler** → *Create Basic Task* → name it (e.g., "Praetorian Daily").
    3.  Trigger: **Daily** at your preferred time.
    4.  Action: **Start a program** with:
        - Program/script: `C:\Windows\System32\wsl.exe`
        - Arguments: `-d Ubuntu /bin/bash -c "/mnt/c/Users/thimo/Dropbox/alberi_don_sturzo/Praetorian/run-praetorian.sh"`
            - Adjust the distribution name (`Ubuntu`) and path if yours differ.
    5.  Save the task. Windows will launch WSL, execute the wrapper, and append output to `praetorian.log`.

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
