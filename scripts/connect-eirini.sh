#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ITECH_ROOT_DEFAULT="$(cd "${REPO_ROOT}/../itech" 2>/dev/null && pwd || true)"

ITECH_ROOT="${ITECH_ROOT:-${ITECH_ROOT_DEFAULT}}"
CONFIG_FILE="${EIRINI_CONFIG_FILE:-${ITECH_ROOT}/keys/eirini-server.ip}"
SSH_KEY_DEFAULT="${ITECH_ROOT}/keys/eirini-private-ssh-key-2026-02-20.key"

if [ -z "${ITECH_ROOT}" ] || [ ! -d "${ITECH_ROOT}" ]; then
  echo "Directory itech non trovata. Imposta ITECH_ROOT oppure usa EIRINI_CONFIG_FILE/SSH_KEY_PATH." >&2
  exit 1
fi

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

if [ "$#" -eq 0 ]; then
  exec ssh \
    -i "${SSH_KEY}" \
    -o StrictHostKeyChecking=accept-new \
    "${REMOTE_USER}@${SERVER_IP}"
fi

exec ssh \
  -i "${SSH_KEY}" \
  -o StrictHostKeyChecking=accept-new \
  "${REMOTE_USER}@${SERVER_IP}" \
  "$@"
