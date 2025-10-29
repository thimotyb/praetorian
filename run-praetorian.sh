#!/bin/bash
set -euo pipefail

TARGET_USER=thimoty
if [[ "${PRAETORIAN_WRAPPER_REEXEC:-0}" != "1" && $(id -un) != "$TARGET_USER" ]]; then
  if command -v runuser >/dev/null 2>&1; then
    exec runuser -u "$TARGET_USER" -- env PRAETORIAN_WRAPPER_REEXEC=1 "$0" "$@"
  elif command -v sudo >/dev/null 2>&1; then
    exec sudo -u "$TARGET_USER" env PRAETORIAN_WRAPPER_REEXEC=1 "$0" "$@"
  else
    echo "Please run this script as user $TARGET_USER or install runuser/sudo." >&2
    exit 1
  fi
fi

REPO_DIR=/mnt/c/Users/thimo/Dropbox/alberi_don_sturzo/Praetorian
LOG_BASENAME=praetorian.log
MAX_LOGS=7

cd "$REPO_DIR"

export HOME="/home/$TARGET_USER"
export XDG_CACHE_HOME="$HOME/.cache"
export PUPPETEER_CACHE_DIR="$HOME/.cache/puppeteer"
mkdir -p "$PUPPETEER_CACHE_DIR"
export PATH="$HOME/.nvm/versions/node/v20.17.0/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

if [[ -f $LOG_BASENAME ]]; then
  timestamp=$(date +%Y%m%d-%H%M%S)
  mv "$LOG_BASENAME" "$LOG_BASENAME.$timestamp"
fi

mapfile -t logs < <({ ls -1t "$LOG_BASENAME".* 2>/dev/null || true; })
if (( ${#logs[@]} > MAX_LOGS )); then
  for old_log in "${logs[@]:MAX_LOGS}"; do
    rm -f "$old_log"
  done
fi

"$HOME/.nvm/versions/node/v20.17.0/bin/npm" start >> "$LOG_BASENAME" 2>&1
