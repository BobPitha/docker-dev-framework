#!/usr/bin/env bash
set -euo pipefail
set -x

: "${HOST_UID:?}"
: "${HOST_GID:?}"
: "${SERVER_USER:?}"
: "${SERVER_GROUP:?}"

EXISTING_USER="$(getent passwd "$HOST_UID" | cut -d: -f1 || true)"
if [[ -n "$EXISTING_USER" && "$EXISTING_USER" != "$SERVER_USER" ]]; then
  userdel -r "$EXISTING_USER" 2>/dev/null || userdel "$EXISTING_USER"
fi

EXISTING_GROUP="$(getent group "$HOST_GID" | cut -d: -f1 || true)"
if [[ -n "$EXISTING_GROUP" && "$EXISTING_GROUP" != "$SERVER_GROUP" ]]; then
  usermod -g "$EXISTING_GROUP" "$SERVER_USER"
  SERVER_GROUP="$EXISTING_GROUP"
else
  groupmod -g "$HOST_GID" "$SERVER_GROUP"
  usermod -g "$SERVER_GROUP" "$SERVER_USER"
fi

usermod -u "$HOST_UID" "$SERVER_USER"

chown -R "$SERVER_USER:$SERVER_GROUP" "/home/$SERVER_USER"

touch /.docker-setup-user-complete