#!/usr/bin/env bash
set -euo pipefail

stage="$1"
hook_dir="/opt/ddf/build-hooks/$stage"

if [[ ! -d "$hook_dir" ]]; then
  echo "No DDF build hook directory for stage: $stage"
  exit 0
fi

shopt -s nullglob
hooks=("$hook_dir"/*.sh)
shopt -u nullglob

if [[ ${#hooks[@]} -eq 0 ]]; then
  echo "No DDF build hooks for stage: $stage"
  exit 0
fi

echo "Running DDF build hooks for stage: $stage"

for hook in "${hooks[@]}"; do
  echo "Running: $hook"
  bash "$hook"
done
