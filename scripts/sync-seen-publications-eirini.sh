#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
if [ -z "${ACTION}" ]; then
  echo "Uso: $0 <upload|download>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ITECH_ROOT_DEFAULT="$(cd "${REPO_ROOT}/../itech" 2>/dev/null && pwd || true)"

ITECH_ROOT="${ITECH_ROOT:-${ITECH_ROOT_DEFAULT}}"
CONFIG_FILE="${EIRINI_CONFIG_FILE:-${ITECH_ROOT}/keys/eirini-server.ip}"
SSH_KEY_DEFAULT="${ITECH_ROOT}/keys/eirini-private-ssh-key-2026-02-20.key"
LOCAL_FILE="${LOCAL_FILE:-${REPO_ROOT}/seen_publications.json}"
REMOTE_FILE="${REMOTE_FILE:-/opt/praetorian/shared/seen_publications.json}"

if [ ! -f "${CONFIG_FILE}" ]; then
  echo "Config server non trovata: ${CONFIG_FILE}" >&2
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

chmod 600 "${SSH_KEY}"

SSH_OPTS=(-i "${SSH_KEY}" -o StrictHostKeyChecking=accept-new)
SSH_DEST="${REMOTE_USER}@${SERVER_IP}"

case "${ACTION}" in
  upload)
    if [ ! -f "${LOCAL_FILE}" ]; then
      echo "File locale non trovato: ${LOCAL_FILE}" >&2
      exit 1
    fi
    echo "[sync] upload ${LOCAL_FILE} -> ${SSH_DEST}:${REMOTE_FILE}"
    scp "${SSH_OPTS[@]}" "${LOCAL_FILE}" "${SSH_DEST}:/tmp/seen_publications.upload.json"
    ssh "${SSH_OPTS[@]}" "${SSH_DEST}" "sudo mkdir -p '$(dirname "${REMOTE_FILE}")' && sudo cp /tmp/seen_publications.upload.json '${REMOTE_FILE}' && sudo chown ${REMOTE_USER}:${REMOTE_USER} '${REMOTE_FILE}' && rm -f /tmp/seen_publications.upload.json"
    ;;
  download)
    echo "[sync] download ${SSH_DEST}:${REMOTE_FILE} -> ${LOCAL_FILE}"
    scp "${SSH_OPTS[@]}" "${SSH_DEST}:${REMOTE_FILE}" "${LOCAL_FILE}"
    ;;
  *)
    echo "Azione non valida: ${ACTION}. Usa upload o download." >&2
    exit 1
    ;;
esac

echo "[sync] completato"
