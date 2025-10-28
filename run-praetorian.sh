#!/bin/bash
set -euo pipefail

REPO_DIR=/mnt/c/Users/thimo/Dropbox/alberi_don_sturzo/Praetorian
LOG_BASENAME=praetorian.log
MAX_LOGS=7

cd "$REPO_DIR"

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

/usr/bin/npm start >> "$LOG_BASENAME" 2>&1
