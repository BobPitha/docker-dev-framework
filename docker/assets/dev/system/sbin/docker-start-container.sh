#!/usr/bin/env bash
set -euo pipefail
set -x

export SERVER_USER=bob
export SERVER_GROUP=bob

/sbin/docker-setup-user.sh
exec /sbin/docker-start-sleep-loop.sh