#!/usr/bin/env bash
#
# Common helpers shared by all build/fetch/install scripts.
#
set -euo pipefail

log() { printf '%s\n' "[$(basename "$0")] $*" >&2; }

die() {
  log "ERROR: $*"
  exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

ensure_tools() {
  local missing=()
  for t in "$@"; do have "$t" || missing+=("$t"); done
  if ((${#missing[@]})); then
    die "Missing tools: ${missing[*]} (please install them)"
  fi
}

copy_config_sub_if_present() {
  local src="${1:-}" dst="${2:-}"
  [[ -n "$src" && -f "$src" && -n "$dst" && -d "$dst" ]] || return 0
  cp -f "$src" "$dst/config.sub" || true
}
