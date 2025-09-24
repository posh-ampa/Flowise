#!/usr/bin/env bash
set -euo pipefail

timestamp() { date -u +"%Y-%m-%dT%H-%M-%SZ"; }

require() {
  if [ -z "${!1:-}" ]; then
    echo "Missing required env: $1" >&2
    exit 1
  fi
}

FLOWISE_DATA_PATH=${FLOWISE_DATA_PATH:-/data/.flowise}
S3_PREFIX=${S3_PREFIX:-flowise/backups/files}
RETENTION_DAYS=${RETENTION_DAYS:-7}

if [ ! -d "$FLOWISE_DATA_PATH" ]; then
  echo "[files-backup] Data path not found: $FLOWISE_DATA_PATH" >&2
  exit 1
fi

USE_S3=0
if [ -n "${BACKUP_S3_BUCKET:-}" ] && [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ] && [ -n "${AWS_DEFAULT_REGION:-}" ]; then
  USE_S3=1
fi

USE_LOCAL=0
if [ -n "${BACKUP_LOCAL_DIR:-}" ]; then
  USE_LOCAL=1
fi

if [ "$USE_S3" -ne 1 ] && [ "$USE_LOCAL" -ne 1 ]; then
  echo "[files-backup] Neither S3 nor local backup target is configured. Set BACKUP_S3_BUCKET (+AWS creds) or BACKUP_LOCAL_DIR." >&2
  exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

FILE="files_${HOSTNAME}_$(timestamp).tar.gz"
PATH_IN_TMP="$TMP_DIR/$FILE"

echo "[files-backup] Archiving $FLOWISE_DATA_PATH ..."
tar -C "$(dirname "$FLOWISE_DATA_PATH")" -czf "$PATH_IN_TMP" "$(basename "$FLOWISE_DATA_PATH")"

if [ "$USE_S3" -eq 1 ]; then
  DEST="s3://${BACKUP_S3_BUCKET}/${S3_PREFIX}/${FILE}"
  echo "[files-backup] Uploading to ${DEST} ..."
  aws s3 cp "$PATH_IN_TMP" "$DEST"
  echo "[files-backup] Applying S3 retention: ${RETENTION_DAYS} days ..."
  aws s3 ls "s3://${BACKUP_S3_BUCKET}/${S3_PREFIX}/" | awk '{print $4}' | while read -r key; do
    ts=$(echo "$key" | sed -n 's/.*_\([0-9T:-]*Z\)\.tar\.gz/\1/p')
    if [ -n "$ts" ]; then
      if [ $(date -d "$ts" +%s) -lt $(date -d "-${RETENTION_DAYS} days" +%s) ]; then
        echo "[files-backup] Deleting old backup: $key"
        aws s3 rm "s3://${BACKUP_S3_BUCKET}/${S3_PREFIX}/$key"
      fi
    fi
  done
fi

if [ "$USE_LOCAL" -eq 1 ]; then
  TARGET_DIR="${BACKUP_LOCAL_DIR%/}/files"
  mkdir -p "$TARGET_DIR"
  cp "$PATH_IN_TMP" "$TARGET_DIR/$FILE"
  echo "[files-backup] Stored local backup at $TARGET_DIR/$FILE"
  echo "[files-backup] Applying local retention: ${RETENTION_DAYS} days in $TARGET_DIR ..."
  find "$TARGET_DIR" -type f -name 'files_*.tar.gz' -mtime +"${RETENTION_DAYS}" -print -delete || true
fi

echo "[files-backup] Done."
