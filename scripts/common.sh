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

# Resolve an artifact from an existing package-local file, an optional cache,
# or one of several URLs. Every candidate is verified before it is installed.
# Usage: fetch <dest_path> <sha256> <chmod+x? (true|false)> [url ...]
fetch() {
  local dest="$1" expected_sha256="$2" make_x="${3:-false}"
  shift 3

  if [[ -f "$dest" && "${FORCE:-0}" != "1" ]]; then
    verify_sha256 "$dest" "$expected_sha256" || die "Refusing to use unverified package-local artifact"
    log "exists: $dest"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  local tmp="${dest}.download.$$"
  local cache_file=""

  if [[ -n "${OPENJTALK_VENDOR_CACHE:-}" && "${FORCE:-0}" != "1" ]]; then
    cache_file="${OPENJTALK_VENDOR_CACHE%/}/$(basename "$dest")"
    if [[ -f "$cache_file" ]]; then
      log "using cache: $cache_file -> $dest"
      if ! cp "$cache_file" "$tmp"; then
        rm -f "$tmp"
        die "Could not copy cached artifact: $cache_file"
      fi

      if ! verify_sha256 "$tmp" "$expected_sha256"; then
        rm -f "$tmp"
        die "Refusing to use unverified cached artifact: $cache_file"
      fi

      mv -f "$tmp" "$dest"
      if [[ "$make_x" == "true" ]]; then chmod +x "$dest" || true; fi
      return 0
    fi
  fi

  if (($# > 0)) && ! have curl; then
    die "Missing tool: curl (or populate OPENJTALK_VENDOR_CACHE)"
  fi

  local url
  for url in "$@"; do
    log "downloading: $url -> $dest"

    # Follow redirects (SF "/download"), fail on HTTP errors, and retry brief
    # transient failures before moving on to the next configured source.
    if ! curl -fL --retry 3 --retry-delay 2 -o "$tmp" "$url"; then
      rm -f "$tmp"
      log "download failed; trying next source: $url"
      continue
    fi

    if ! verify_sha256 "$tmp" "$expected_sha256"; then
      rm -f "$tmp"
      log "rejected unverified source; trying next source: $url"
      continue
    fi

    mv -f "$tmp" "$dest"
    if [[ "$make_x" == "true" ]]; then chmod +x "$dest" || true; fi
    return 0
  done

  log "ERROR: Failed to obtain $(basename "$dest")."
  if [[ -n "${OPENJTALK_VENDOR_CACHE:-}" ]]; then
    log "Checked cache: ${cache_file:-${OPENJTALK_VENDOR_CACHE%/}/$(basename "$dest")}"
  else
    log "OPENJTALK_VENDOR_CACHE is not configured."
  fi
  if (($# > 0)); then
    log "Checked download sources:"
    for url in "$@"; do log "  $url"; done
  else
    log "No download sources are configured."
  fi
  log "Expected SHA-256: $expected_sha256"
  die "Retry later or place the expected artifact in OPENJTALK_VENDOR_CACHE"
}
