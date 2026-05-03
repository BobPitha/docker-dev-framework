#!/usr/bin/env bash
set -euo pipefail

: "${SERVER_USER:?SERVER_USER not set}"
: "${SERVER_GROUP:?SERVER_GROUP not set}"

/sbin/docker-setup-user.sh
exec /sbin/docker-start-sleep-loop.sh