#!/usr/bin/env bash
set -euo pipefail

APP_BASE="${APP_BASE:-/opt/praetorian}"
SOURCE_DIR="${SOURCE_DIR:?SOURCE_DIR non definita}"
RELEASE_NAME="${RELEASE_NAME:?RELEASE_NAME non definita}"
RELEASES_TO_KEEP="${RELEASES_TO_KEEP:-5}"
SEEN_STATE_TMP_PATH="${SEEN_STATE_TMP_PATH:-}"
SEEN_STATE_MODE="${SEEN_STATE_MODE:-if-missing}" # if-missing|force-upload|keep-remote
ENV_TMP_PATH="${ENV_TMP_PATH:-}"
ENV_MODE="${ENV_MODE:-if-missing}" # if-missing|force-upload|keep-remote
RUN_AFTER_DEPLOY="${RUN_AFTER_DEPLOY:-false}"
TIMER_ON_CALENDAR="${TIMER_ON_CALENDAR:-*-*-* 07:15:00}"
INSTALL_CHROMIUM_DEPS="${INSTALL_CHROMIUM_DEPS:-false}"
REMOTE_USER="${REMOTE_USER:-ubuntu}"

if [ ! -d "${SOURCE_DIR}" ]; then
  echo "SOURCE_DIR non trovata: ${SOURCE_DIR}" >&2
  exit 1
fi

run_root() {
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    "$@"
  fi
}

if [ "${INSTALL_CHROMIUM_DEPS}" = "true" ]; then
  echo "[remote] installo dipendenze Chromium"
  run_root apt-get update
  run_root apt-get install -y --no-install-recommends \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libexpat1 \
    libfontconfig1 \
    libgbm1 \
    libgtk-3-0 \
    libnss3 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libstdc++6 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    xdg-utils
fi

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js non trovato sul server. Installa Node 20+ e rilancia il deploy." >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm non trovato sul server. Installa npm e rilancia il deploy." >&2
  exit 1
fi

RELEASES_DIR="${APP_BASE}/releases"
SHARED_DIR="${APP_BASE}/shared"
RELEASE_DIR="${RELEASES_DIR}/${RELEASE_NAME}"
CURRENT_LINK="${APP_BASE}/current"
SEEN_STATE_TARGET="${SHARED_DIR}/seen_publications.json"
ENV_TARGET="${SHARED_DIR}/.env"

run_root mkdir -p "${RELEASES_DIR}" "${SHARED_DIR}"
run_root chown -R "${REMOTE_USER}:${REMOTE_USER}" "${APP_BASE}"

if [ ! -f "${SEEN_STATE_TARGET}" ]; then
  echo "[]" > /tmp/seen_publications.bootstrap.json
  run_root mv /tmp/seen_publications.bootstrap.json "${SEEN_STATE_TARGET}"
  run_root chown "${REMOTE_USER}:${REMOTE_USER}" "${SEEN_STATE_TARGET}"
fi

if [ ! -f "${ENV_TARGET}" ]; then
  if [ -f "${SOURCE_DIR}/env.example" ]; then
    run_root cp "${SOURCE_DIR}/env.example" "${ENV_TARGET}"
  else
    run_root touch "${ENV_TARGET}"
  fi
  run_root chown "${REMOTE_USER}:${REMOTE_USER}" "${ENV_TARGET}"
  run_root chmod 600 "${ENV_TARGET}"
  echo "[remote] creato ${ENV_TARGET}: compilare SMTP_* prima del primo run"
fi

case "${SEEN_STATE_MODE}" in
  keep-remote)
    echo "[remote] stato pubblicazioni: mantengo file remoto esistente"
    ;;
  if-missing)
    if [ -n "${SEEN_STATE_TMP_PATH}" ] && [ -f "${SEEN_STATE_TMP_PATH}" ] && [ ! -s "${SEEN_STATE_TARGET}" ]; then
      run_root cp "${SEEN_STATE_TMP_PATH}" "${SEEN_STATE_TARGET}"
      run_root chown "${REMOTE_USER}:${REMOTE_USER}" "${SEEN_STATE_TARGET}"
      echo "[remote] stato pubblicazioni caricato (remote file vuoto/non presente)"
    else
      echo "[remote] stato pubblicazioni non sovrascritto (modalita if-missing)"
    fi
    ;;
  force-upload)
    if [ -n "${SEEN_STATE_TMP_PATH}" ] && [ -f "${SEEN_STATE_TMP_PATH}" ]; then
      run_root cp "${SEEN_STATE_TMP_PATH}" "${SEEN_STATE_TARGET}"
      run_root chown "${REMOTE_USER}:${REMOTE_USER}" "${SEEN_STATE_TARGET}"
      echo "[remote] stato pubblicazioni sovrascritto da upload locale"
    else
      echo "[remote] force-upload richiesto ma file stato locale mancante" >&2
      exit 1
    fi
    ;;
  *)
    echo "SEEN_STATE_MODE non valida: ${SEEN_STATE_MODE}" >&2
    exit 1
    ;;
esac

case "${ENV_MODE}" in
  keep-remote)
    echo "[remote] env runtime: mantengo file remoto esistente"
    ;;
  if-missing)
    if [ -n "${ENV_TMP_PATH}" ] && [ -f "${ENV_TMP_PATH}" ] && [ ! -s "${ENV_TARGET}" ]; then
      run_root cp "${ENV_TMP_PATH}" "${ENV_TARGET}"
      run_root chown "${REMOTE_USER}:${REMOTE_USER}" "${ENV_TARGET}"
      run_root chmod 600 "${ENV_TARGET}"
      echo "[remote] env runtime caricato (remote file vuoto/non presente)"
    else
      echo "[remote] env runtime non sovrascritto (modalita if-missing)"
    fi
    ;;
  force-upload)
    if [ -n "${ENV_TMP_PATH}" ] && [ -f "${ENV_TMP_PATH}" ]; then
      run_root cp "${ENV_TMP_PATH}" "${ENV_TARGET}"
      run_root chown "${REMOTE_USER}:${REMOTE_USER}" "${ENV_TARGET}"
      run_root chmod 600 "${ENV_TARGET}"
      echo "[remote] env runtime sovrascritto da upload locale"
    else
      echo "[remote] force-upload env richiesto ma file .env locale mancante" >&2
      exit 1
    fi
    ;;
  *)
    echo "ENV_MODE non valida: ${ENV_MODE}" >&2
    exit 1
    ;;
esac

run_root rm -rf "${RELEASE_DIR}"
run_root mkdir -p "${RELEASE_DIR}"
run_root rsync -a --delete "${SOURCE_DIR}/" "${RELEASE_DIR}/"
run_root chown -R "${REMOTE_USER}:${REMOTE_USER}" "${RELEASE_DIR}"

run_root ln -sfn "${ENV_TARGET}" "${RELEASE_DIR}/.env"
run_root ln -sfn "${SEEN_STATE_TARGET}" "${RELEASE_DIR}/seen_publications.json"

(
  cd "${RELEASE_DIR}"
  npm ci
)

run_root ln -sfn "${RELEASE_DIR}" "${CURRENT_LINK}"

SERVICE_TMP="/tmp/praetorian.service.${RANDOM}.tmp"
TIMER_TMP="/tmp/praetorian.timer.${RANDOM}.tmp"

cat > "${SERVICE_TMP}" <<SERVICE
[Unit]
Description=Praetorian scraper run
After=network-online.target

[Service]
Type=oneshot
User=${REMOTE_USER}
WorkingDirectory=${CURRENT_LINK}
Environment=PUPPETEER_CACHE_DIR=/home/${REMOTE_USER}/.cache/puppeteer
EnvironmentFile=-${ENV_TARGET}
ExecStart=/usr/bin/npm start

[Install]
WantedBy=multi-user.target
SERVICE

cat > "${TIMER_TMP}" <<TIMER
[Unit]
Description=Run Praetorian scraper daily

[Timer]
OnCalendar=${TIMER_ON_CALENDAR}
Persistent=true
RandomizedDelaySec=180
Unit=praetorian.service

[Install]
WantedBy=timers.target
TIMER

run_root mv "${SERVICE_TMP}" /etc/systemd/system/praetorian.service
run_root mv "${TIMER_TMP}" /etc/systemd/system/praetorian.timer
run_root systemctl daemon-reload
run_root systemctl enable --now praetorian.timer

if [ "${RUN_AFTER_DEPLOY}" = "true" ]; then
  echo "[remote] eseguo run immediato praetorian.service"
  run_root systemctl start praetorian.service
fi

echo "[remote] pulizia release vecchie (keep=${RELEASES_TO_KEEP})"
ls -1dt "${RELEASES_DIR}"/* 2>/dev/null | tail -n +$((RELEASES_TO_KEEP + 1)) | while read -r old_release; do
  run_root rm -rf "${old_release}"
done

echo "[remote] deploy completato"
run_root systemctl status praetorian.timer --no-pager --lines=0 || true
