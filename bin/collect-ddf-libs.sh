#!/usr/bin/env bash
set -euo pipefail

DDF_FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${DDF_FRAMEWORK_ROOT}/config/ddf-host.env"

rm -rf "${DDF_GENERATED_LIBS_DIR}"
mkdir -p "${DDF_GENERATED_LIBS_DIR}"

if [ ! -d "${DDF_LIBS_CACHE_DIR}" ]; then
  echo "No DDF libs cache directory: ${DDF_LIBS_CACHE_DIR}"
  exit 0
fi

for f in "${DDF_LIBS_CACHE_DIR}"/*; do
  [ -f "$f" ] || continue

  dest="${DDF_GENERATED_LIBS_DIR}/$(basename "$f")"
  rm -f "$dest"

  ln "$f" "$dest" 2>/dev/null || cp "$f" "$dest"
done
