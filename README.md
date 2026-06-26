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
    On ARM servers running under systemd, avoid snap Chromium and set `PRAETORIAN_BROWSER_EXECUTABLE_PATH` to a native Chromium wrapper.
    You can tune per-keyword retries with `PRAETORIAN_KEYWORD_TIMEOUT_MS` and `PRAETORIAN_KEYWORD_MAX_ATTEMPTS`.

2.  **Keywords & Emails**: The `config.json` file contains the keywords to search for and the email recipients. You can edit this file directly if needed.

## 3. Running the Script

You can run the script manually with the following command:

```bash
npm start
```

If you prefer to exercise the wrapper that Task Scheduler uses (and generate the rotated log files), invoke:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\praetorian-task-run.ps1
```

or inside WSL:

```bash
/mnt/c/Windows/System32/wsl.exe -d Ubuntu-20.04 /bin/bash -c "/mnt/c/Users/thimo/Dropbox/alberi_don_sturzo/Praetorian/run-praetorian.sh"
```

The wrapper will automatically re-exec as the `thimoty` user if invoked as `root`, ensuring Puppeteer finds the cached Chrome bundle.

## 3.b Deploy on Eirini Server (using `../itech` access config)

This repository includes deploy helpers to publish Praetorian on the same OCI VM used by Eirini, reusing:

- `../itech/keys/eirini-server.ip`
- `../itech/keys/eirini-private-ssh-key-2026-02-20.key`

Scripts added:

- `scripts/connect-eirini.sh` -> SSH connection to server.
- `scripts/deploy-praetorian-eirini.sh` -> upload/update app release + systemd timer setup.
- `scripts/configure_praetorian_remote.sh` -> remote helper executed by deploy script.
- `scripts/sync-seen-publications-eirini.sh` -> manual upload/download of `seen_publications.json`.

### First deploy (with state migration)

1. Ensure local state file is up to date:
   ```bash
   ls -l seen_publications.json
   ```
2. Run initial deploy and force state upload:
   ```bash
   SEEN_STATE_MODE=force-upload ENV_MODE=force-upload bash scripts/deploy-praetorian-eirini.sh
   ```
3. On server, edit SMTP settings:
   ```bash
   bash scripts/connect-eirini.sh
   sudo nano /opt/praetorian/shared/.env
   ```
4. Optional immediate test run:
   ```bash
   bash scripts/connect-eirini.sh "sudo systemctl start praetorian.service && sudo journalctl -u praetorian.service -n 120 --no-pager"
   ```

### Deploy updates (normal flow)

For subsequent releases, keep remote state by default:

```bash
bash scripts/deploy-praetorian-eirini.sh
```

Useful overrides:

- `SEEN_STATE_MODE=keep-remote` (explicitly never upload local state)
- `SEEN_STATE_MODE=if-missing` (default; upload only if remote state is missing/empty)
- `SEEN_STATE_MODE=force-upload` (overwrite remote state with local file)
- `ENV_MODE=keep-remote` (default; keep remote `.env`)
- `ENV_MODE=force-upload` (overwrite remote `.env` with local `.env`)
- `RUN_AFTER_DEPLOY=true` (start one run immediately after deployment)
- `TIMER_ON_CALENDAR='*-*-* 06:30:00'` (change daily schedule)
- `INSTALL_CHROMIUM_DEPS=true` (install Chromium OS packages on remote host)

### Manual state sync

Upload local state to server:

```bash
bash scripts/sync-seen-publications-eirini.sh upload
```

Download server state to local repository:

```bash
bash scripts/sync-seen-publications-eirini.sh download
```

For automatic daily execution, you can either:

-   Run it in your cloud environment (e.g., GitHub Actions, Vercel Cron Jobs, AWS Lambda Scheduled Events).
-   Or schedule it locally on Windows (WSL2) using Task Scheduler:

    1.  Ensure the repository contains `run-praetorian.sh` (wrapper script). Make it executable: `chmod +x run-praetorian.sh`.
    2.  Open **Task Scheduler** → *Create Basic Task* → name it (e.g., "Praetorian").
    3.  Trigger: **Daily** at your preferred time.
    4.  Action: **Start a program** with:
        - Program/script: `C:\Windows\System32\wsl.exe`
        - Arguments: `-d Ubuntu-20.04 /bin/bash -c "/mnt/c/Users/thimo/Dropbox/alberi_don_sturzo/Praetorian/run-praetorian.sh"`
            - Replace `Ubuntu-20.04` with the name returned by `wsl -l -q` on your machine, if different.
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
