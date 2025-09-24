#!/usr/bin/env sh
set -e
ENV_FILE=${ENV_FILE:-/app/env}
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi
exec "$@"
