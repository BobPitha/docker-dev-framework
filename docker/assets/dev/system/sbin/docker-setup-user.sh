#!/usr/bin/env bash
set -euo pipefail

: "${HOST_UID:?HOST_UID not set}"
: "${HOST_GID:?HOST_GID not set}"
: "${SERVER_USER:?SERVER_USER not set}"
: "${SERVER_GROUP:?SERVER_GROUP not set}"

# Skip if already matching (speeds up subsequent starts)
CURRENT_UID="$(id -u "$SERVER_USER" 2>/dev/null || echo 0)"
CURRENT_GID="$(id -g "$SERVER_USER" 2>/dev/null || echo 0)"

if [[ "$CURRENT_UID" -eq "$HOST_UID" && "$CURRENT_GID" -eq "$HOST_GID" ]]; then
    touch /.docker-setup-user-complete
    exit 0
fi

# Handle UID mapping
EXISTING_USER="$(getent passwd "$HOST_UID" | cut -d: -f1 || true)"
if [[ -n "$EXISTING_USER" && "$EXISTING_USER" != "$SERVER_USER" ]]; then
    userdel -r "$EXISTING_USER" 2>/dev/null || userdel "$EXISTING_USER"
fi

# Handle GID mapping (gracefully handle conflicts)
EXISTING_GROUP="$(getent group "$HOST_GID" | cut -d: -f1 || true)"
if [[ -n "$EXISTING_GROUP" && "$EXISTING_GROUP" != "$SERVER_GROUP" ]]; then
    usermod -g "$EXISTING_GROUP" "$SERVER_USER"
else
    groupmod -g "$HOST_GID" "$SERVER_GROUP"
    usermod -g "$SERVER_GROUP" "$SERVER_USER"
fi

usermod -u "$HOST_UID" "$SERVER_USER" 
chown -R "$HOST_UID:$HOST_GID" "/home/$SERVER_USER" 2>/dev/null || true

touch /.docker-setup-user-complete
