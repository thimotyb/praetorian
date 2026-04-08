#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ITECH_ROOT_DEFAULT="$(cd "${REPO_ROOT}/../itech" 2>/dev/null && pwd || true)"

ITECH_ROOT="${ITECH_ROOT:-${ITECH_ROOT_DEFAULT}}"
CONFIG_FILE="${EIRINI_CONFIG_FILE:-${ITECH_ROOT}/keys/eirini-server.ip}"
SSH_KEY_DEFAULT="${ITECH_ROOT}/keys/eirini-private-ssh-key-2026-02-20.key"
REMOTE_HELPER_LOCAL="${REPO_ROOT}/scripts/configure_praetorian_remote.sh"

APP_BASE="${APP_BASE:-/opt/praetorian}"
RELEASES_TO_KEEP="${RELEASES_TO_KEEP:-5}"
TIMER_ON_CALENDAR="${TIMER_ON_CALENDAR:-*-*-* 07:15:00}"
SEEN_STATE_MODE="${SEEN_STATE_MODE:-if-missing}"   # if-missing|force-upload|keep-remote
ENV_MODE="${ENV_MODE:-keep-remote}"                # if-missing|force-upload|keep-remote
RUN_AFTER_DEPLOY="${RUN_AFTER_DEPLOY:-false}"
INSTALL_CHROMIUM_DEPS="${INSTALL_CHROMIUM_DEPS:-false}"

if [ -z "${ITECH_ROOT}" ] || [ ! -d "${ITECH_ROOT}" ]; then
  echo "Directory itech non trovata. Imposta ITECH_ROOT oppure usa EIRINI_CONFIG_FILE/SSH_KEY_PATH." >&2
  exit 1
fi

if [ ! -f "${CONFIG_FILE}" ]; then
  echo "Config server non trovata: ${CONFIG_FILE}" >&2
  exit 1
fi

if [ ! -f "${REMOTE_HELPER_LOCAL}" ]; then
  echo "Helper remoto non trovato: ${REMOTE_HELPER_LOCAL}" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${CONFIG_FILE}"

SERVER_IP="${EIRINI_SERVER_IP:?EIRINI_SERVER_IP non definito}"
REMOTE_USER="${EIRINI_SERVER_SSH_USER:-ubuntu}"
SSH_KEY="${SSH_KEY_PATH:-${SSH_KEY_DEFAULT}}"

if [ ! -f "${SSH_KEY}" ]; then
  echo "Chiave SSH non trovata: ${SSH_KEY}" >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync non trovato in locale." >&2
  exit 1
fi

chmod 600 "${SSH_KEY}"

STAMP="$(date +%Y%m%d%H%M%S)"
RELEASE_NAME="release-${STAMP}"
REMOTE_TMP_BASE="/tmp/praetorian-deploy-${STAMP}"
REMOTE_SRC_DIR="${REMOTE_TMP_BASE}/src"
REMOTE_HELPER_PATH="${REMOTE_TMP_BASE}/configure_praetorian_remote.sh"
REMOTE_SEEN_PATH="${REMOTE_TMP_BASE}/seen_publications.json"
REMOTE_ENV_PATH="${REMOTE_TMP_BASE}/runtime.env"

SSH_OPTS=(-i "${SSH_KEY}" -o StrictHostKeyChecking=accept-new)
SSH_DEST="${REMOTE_USER}@${SERVER_IP}"

echo "[local] preparo cartelle temporanee su ${SSH_DEST}"
ssh "${SSH_OPTS[@]}" "${SSH_DEST}" "mkdir -p '${REMOTE_SRC_DIR}'"

echo "[local] upload sorgenti praetorian"
rsync -az --delete \
  --exclude '.git' \
  --exclude 'node_modules' \
  --exclude '.env' \
  --exclude 'dist' \
  --exclude '*.log' \
  --exclude '.DS_Store' \
  --exclude 'seen_publications.json' \
  -e "ssh ${SSH_OPTS[*]}" \
  "${REPO_ROOT}/" "${SSH_DEST}:${REMOTE_SRC_DIR}/"

echo "[local] upload helper remoto"
scp "${SSH_OPTS[@]}" "${REMOTE_HELPER_LOCAL}" "${SSH_DEST}:${REMOTE_HELPER_PATH}"

if [ "${SEEN_STATE_MODE}" != "keep-remote" ] && [ -f "${REPO_ROOT}/seen_publications.json" ]; then
  echo "[local] upload seen_publications.json (${SEEN_STATE_MODE})"
  scp "${SSH_OPTS[@]}" "${REPO_ROOT}/seen_publications.json" "${SSH_DEST}:${REMOTE_SEEN_PATH}"
else
  echo "[local] nessun upload stato locale (mode=${SEEN_STATE_MODE})"
  REMOTE_SEEN_PATH=""
fi

if [ "${ENV_MODE}" != "keep-remote" ] && [ -f "${REPO_ROOT}/.env" ]; then
  echo "[local] upload .env runtime (${ENV_MODE})"
  scp "${SSH_OPTS[@]}" "${REPO_ROOT}/.env" "${SSH_DEST}:${REMOTE_ENV_PATH}"
else
  echo "[local] nessun upload .env locale (mode=${ENV_MODE})"
  REMOTE_ENV_PATH=""
fi

REMOTE_CMD="$(printf "chmod +x %q && APP_BASE=%q SOURCE_DIR=%q RELEASE_NAME=%q RELEASES_TO_KEEP=%q SEEN_STATE_TMP_PATH=%q SEEN_STATE_MODE=%q ENV_TMP_PATH=%q ENV_MODE=%q RUN_AFTER_DEPLOY=%q TIMER_ON_CALENDAR=%q INSTALL_CHROMIUM_DEPS=%q REMOTE_USER=%q %q" \
  "${REMOTE_HELPER_PATH}" \
  "${APP_BASE}" \
  "${REMOTE_SRC_DIR}" \
  "${RELEASE_NAME}" \
  "${RELEASES_TO_KEEP}" \
  "${REMOTE_SEEN_PATH}" \
  "${SEEN_STATE_MODE}" \
  "${REMOTE_ENV_PATH}" \
  "${ENV_MODE}" \
  "${RUN_AFTER_DEPLOY}" \
  "${TIMER_ON_CALENDAR}" \
  "${INSTALL_CHROMIUM_DEPS}" \
  "${REMOTE_USER}" \
  "${REMOTE_HELPER_PATH}")"

echo "[local] eseguo deploy remoto"
ssh "${SSH_OPTS[@]}" "${SSH_DEST}" "${REMOTE_CMD}"

echo "[local] pulizia temp remoto"
ssh "${SSH_OPTS[@]}" "${SSH_DEST}" "rm -rf '${REMOTE_TMP_BASE}'"

echo "[local] verifica timer"
ssh "${SSH_OPTS[@]}" "${SSH_DEST}" "systemctl status praetorian.timer --no-pager --lines=2 || true"

echo "[local] deploy Praetorian completato"
echo "[local] release attiva: ${RELEASE_NAME}"
