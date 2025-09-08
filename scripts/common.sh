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
  # Require: src exists and dst is a directory.
  [[ -n "$src" && -f "$src" && -n "$dst" && -d "$dst" ]] || return 0

  log "Copying $(basename "$src") to $dst/config.sub (and config.guess if present)."
  cp -f "$src" "$dst/config.sub" || true

  # Also copy into $dst/config/config.sub which some projects expect.
  if [[ -d "$dst/config" ]]; then
    log "Also copying $(basename "$src") to $dst/config/config.sub"
    cp -f "$src" "$dst/config/config.sub" || true
  else
    # create config/ and copy (safer for projects that reference config/config.sub)
    mkdir -p "$dst/config"
    cp -f "$src" "$dst/config/config.sub" || true
  fi

  # If there is a config.guess sibling next to the provided config.sub, copy it too.
  local guess="$(dirname "$src")/config.guess"
  if [[ -f "$guess" ]]; then
    log "Copying config.guess alongside config.sub"
    cp -f "$guess" "$dst/config.guess" || true
    cp -f "$guess" "$dst/config/config.guess" || true
  fi
}

