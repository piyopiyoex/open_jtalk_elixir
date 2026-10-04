#!/usr/bin/env bash
#
# Common helpers
#
set -euo pipefail

# Log to stderr with the script's basename as a prefix.
log() { printf '%s\n' "[$(basename "$0")] $*" >&2; }

# Fail fast with a consistent error line.
die() {
  log "ERROR: $*"
  exit 1
}

# True if a program exists on PATH.
have() { command -v "$1" >/dev/null 2>&1; }

# Ensure a set of tools exist. If any are missing, exit with a helpful message.
ensure_tools() {
  local missing=()
  for t in "$@"; do have "$t" || missing+=("$t"); done
  ((${#missing[@]} == 0)) || die "Missing tools: ${missing[*]}"
}

# Calculate a SHA-256 digest with the tool available on Linux or macOS.
sha256_file() {
  local path="$1"
  if have sha256sum; then
    sha256sum "$path" | awk '{print $1}'
  elif have shasum; then
    shasum -a 256 "$path" | awk '{print $1}'
  else
    die "Missing SHA-256 tool: install sha256sum or shasum"
  fi
}

verify_sha256() {
  local path="$1" expected="$2" actual
  actual="$(sha256_file "$path")"
  if [[ "$actual" != "$expected" ]]; then
    log "ERROR: SHA-256 mismatch for $path (expected $expected, got $actual)"
    return 1
  fi
}

# Fetch and verify a URL before atomically installing it at the destination.
# Usage: fetch <url> <dest_path> <sha256> [chmod+x? (true|false)]
fetch() {
  local url="$1" dest="$2" expected_sha256="$3" make_x="${4:-false}"
  if [[ -f "$dest" && "${FORCE:-0}" != "1" ]]; then
    verify_sha256 "$dest" "$expected_sha256" || die "Refusing to use unverified download"
    log "exists: $dest"
    return 0
  fi

  log "downloading: $url -> $dest"
  mkdir -p "$(dirname "$dest")"
  local tmp="${dest}.download.$$"

  # Follow redirects (SF “/download”), fail on HTTP errors, retry a bit for flakiness
  if ! curl -fL --retry 3 --retry-delay 2 -o "$tmp" "$url"; then
    rm -f "$tmp"
    die "Download failed: $url"
  fi

  if ! verify_sha256 "$tmp" "$expected_sha256"; then
    rm -f "$tmp"
    die "Refusing to install unverified download"
  fi

  mv -f "$tmp" "$dest"
  if [[ "$make_x" == "true" ]]; then chmod +x "$dest" || true; fi
}
