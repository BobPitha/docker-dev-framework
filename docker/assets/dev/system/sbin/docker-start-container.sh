#!/usr/bin/env bash
set -euo pipefail

: "${SERVER_USER:?SERVER_USER not set}"
: "${SERVER_GROUP:?SERVER_GROUP not set}"

if [ -d /etc/ddf/env.d ]; then
  for f in /etc/ddf/env.d/*.sh; do
    [ -f "$f" ] && . "$f"
  done
fi

/sbin/docker-setup-user.sh
exec /sbin/docker-start-sleep-loop.sh