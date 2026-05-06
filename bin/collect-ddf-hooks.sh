#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_CONFIG="${ROOT_DIR}/workspace-config/workspace_dirs.bash"
OUT_ROOT="${ROOT_DIR}/.generated/ddf-build-hooks"

STAGES=(base dev-core dev-tooling dev-gui prod)

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

for stage in "${STAGES[@]}"; do
  mkdir -p "$OUT_ROOT/$stage"
  printf 'generated_file\toriginal_file\trepo_dir\trepo_name\tstage\thook_group\n' \
    > "$OUT_ROOT/$stage/manifest.tsv"
done

source "$WORKSPACE_CONFIG"

sanitize_name() {
  basename "$1" | tr -cd '[:alnum:]_.-'
}

copy_hook() {
  local src="$1"
  local stage="$2"
  local repo_dir="$3"
  local repo_name="$4"
  local group="$5"
  local ordinal="$6"

  [[ -f "$src" ]] || return 0

  local base dest_name dest
  base="$(basename "$src")"
  dest_name="${repo_name}__${ordinal}__${base}"
  dest="$OUT_ROOT/$stage/$dest_name"

  cp "$src" "$dest"
  chmod +x "$dest"

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$dest_name" "$src" "$repo_dir" "$repo_name" "$stage" "$group" \
    >> "$OUT_ROOT/$stage/manifest.tsv"
}

copy_dir_hooks() {
  local src_dir="$1"
  local stage="$2"
  local repo_dir="$3"
  local repo_name="$4"
  local group="$5"
  local ordinal="$6"

  [[ -d "$src_dir" ]] || return 0

  find "$src_dir" -maxdepth 1 -type f -name '*.sh' -print \
    | sort \
    | while IFS= read -r src; do
        copy_hook "$src" "$stage" "$repo_dir" "$repo_name" "$group" "$ordinal"
      done
}

for repo_dir in "${WORKSPACE_DIRS[@]}"; do
  repo_dir="$(eval "printf '%s' \"$repo_dir\"")"
  [[ -d "$repo_dir" ]] || continue

  repo_name="$(sanitize_name "$repo_dir")"

  for stage in "${STAGES[@]}"; do
    build_dir="$repo_dir/.ddf/build"

    copy_hook      "$build_dir/all.sh"       "$stage" "$repo_dir" "$repo_name" "all-file"   "00"
    copy_dir_hooks "$build_dir/all"          "$stage" "$repo_dir" "$repo_name" "all-dir"    "01"
    copy_hook      "$build_dir/${stage}.sh"  "$stage" "$repo_dir" "$repo_name" "stage-file" "10"
    copy_dir_hooks "$build_dir/${stage}"     "$stage" "$repo_dir" "$repo_name" "stage-dir"  "11"
  done
done