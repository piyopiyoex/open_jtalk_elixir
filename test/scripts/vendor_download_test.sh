#!/usr/bin/env bash
# shellcheck disable=SC2218 # fetch helpers are loaded with source before use.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

assert_file_equals() {
  local expected="$1" actual="$2"
  cmp "$expected" "$actual" || die "Files differ: $expected and $actual"
}

assert_contains() {
  local expected="$1" path="$2"
  grep -F "$expected" "$path" >/dev/null || die "Missing '$expected' in $path"
}

assert_not_contains() {
  local unexpected="$1" path="$2"
  if grep -F "$unexpected" "$path" >/dev/null; then
    die "Unexpected '$unexpected' in $path"
  fi
}

printf 'verified vendor payload\n' >"$TEST_DIR/good"
printf 'unexpected vendor payload\n' >"$TEST_DIR/bad"
GOOD_SHA256="$(sha256_file "$TEST_DIR/good")"

# Existing package-local artifacts are verified and reused without downloading.
mkdir -p "$TEST_DIR/existing"
cp "$TEST_DIR/good" "$TEST_DIR/existing/artifact.tar.gz"
fetch \
  "$TEST_DIR/existing/artifact.tar.gz" \
  "$GOOD_SHA256" \
  false \
  "file://$TEST_DIR/does-not-exist"

# A complete cache supports resolution without any URL candidates.
mkdir -p "$TEST_DIR/cache" "$TEST_DIR/from-cache"
cp "$TEST_DIR/good" "$TEST_DIR/cache/artifact.tar.gz"
OPENJTALK_VENDOR_CACHE="$TEST_DIR/cache"
fetch "$TEST_DIR/from-cache/artifact.tar.gz" "$GOOD_SHA256" false
assert_file_equals "$TEST_DIR/good" "$TEST_DIR/from-cache/artifact.tar.gz"
unset OPENJTALK_VENDOR_CACHE

# Failed and checksum-invalid candidates are rejected before a valid fallback.
mkdir -p "$TEST_DIR/from-fallback"
fetch \
  "$TEST_DIR/from-fallback/artifact.tar.gz" \
  "$GOOD_SHA256" \
  false \
  "file://$TEST_DIR/missing" \
  "file://$TEST_DIR/bad" \
  "file://$TEST_DIR/good"
assert_file_equals "$TEST_DIR/good" "$TEST_DIR/from-fallback/artifact.tar.gz"

# An invalid explicit cache entry fails closed instead of being hidden by the
# network fallback.
mkdir -p "$TEST_DIR/bad-cache" "$TEST_DIR/from-bad-cache"
cp "$TEST_DIR/bad" "$TEST_DIR/bad-cache/artifact.tar.gz"
if (
  # shellcheck disable=SC2030 # Deliberately scoped to this failure case.
  OPENJTALK_VENDOR_CACHE="$TEST_DIR/bad-cache"
  fetch \
    "$TEST_DIR/from-bad-cache/artifact.tar.gz" \
    "$GOOD_SHA256" \
    false \
    "file://$TEST_DIR/good"
) >"$TEST_DIR/bad-cache.log" 2>&1; then
  die "Invalid cached artifact was accepted"
fi
assert_contains "Refusing to use unverified cached artifact" "$TEST_DIR/bad-cache.log"
[[ ! -e "$TEST_DIR/from-bad-cache/artifact.tar.gz" ]] || die "Invalid cache was installed"

# Exhausted candidates report the artifact, sources, digest, and cache remedy.
if (
  fetch \
    "$TEST_DIR/unavailable/artifact.tar.gz" \
    "$GOOD_SHA256" \
    false \
    "file://$TEST_DIR/missing"
) >"$TEST_DIR/unavailable.log" 2>&1; then
  die "Unavailable artifact unexpectedly resolved"
fi
assert_contains "Failed to obtain artifact.tar.gz" "$TEST_DIR/unavailable.log"
assert_contains "file://$TEST_DIR/missing" "$TEST_DIR/unavailable.log"
assert_contains "Expected SHA-256: $GOOD_SHA256" "$TEST_DIR/unavailable.log"
assert_contains "OPENJTALK_VENDOR_CACHE" "$TEST_DIR/unavailable.log"

# The preparation groups keep native sources and optional assets independent.
# shellcheck source=scripts/prepare_vendor.sh
source "$ROOT_DIR/scripts/prepare_vendor.sh"
VENDOR_DIR="$TEST_DIR/grouped-vendor"
FETCH_LOG="$TEST_DIR/fetch.log"

# Default candidates, a prepended mirror, and per-artifact overrides retain
# their documented ordering.
fetch() {
  printf '%s\n' "$@" >"$FETCH_LOG"
}
unset OPENJTALK_TEST_URLS OPENJTALK_VENDOR_MIRROR_URL
fetch_artifact \
  "artifact.tar.gz" \
  "$GOOD_SHA256" \
  "OPENJTALK_TEST_URLS" \
  "https://upstream.example/one" \
  "https://upstream.example/two"
assert_contains "https://upstream.example/one" "$FETCH_LOG"
assert_contains "https://upstream.example/two" "$FETCH_LOG"

OPENJTALK_VENDOR_MIRROR_URL="https://mirror.example/vendor-v1"
fetch_artifact \
  "artifact.tar.gz" \
  "$GOOD_SHA256" \
  "OPENJTALK_TEST_URLS" \
  "https://upstream.example/one"
assert_contains "https://mirror.example/vendor-v1/artifact.tar.gz" "$FETCH_LOG"
assert_contains "https://upstream.example/one" "$FETCH_LOG"

export OPENJTALK_TEST_URLS="https://custom.example/one https://custom.example/two"
fetch_artifact \
  "artifact.tar.gz" \
  "$GOOD_SHA256" \
  "OPENJTALK_TEST_URLS" \
  "https://upstream.example/one"
assert_contains "https://custom.example/one" "$FETCH_LOG"
assert_contains "https://custom.example/two" "$FETCH_LOG"
assert_not_contains "https://mirror.example" "$FETCH_LOG"
assert_not_contains "https://upstream.example" "$FETCH_LOG"
unset OPENJTALK_TEST_URLS OPENJTALK_VENDOR_MIRROR_URL

fetch_artifact() {
  printf '%s\n' "$1" >>"$FETCH_LOG"
}

: >"$FETCH_LOG"
prepare_native_sources
assert_contains "open_jtalk-1.11.tar.gz" "$FETCH_LOG"
assert_contains "hts_engine_API-1.10.tar.gz" "$FETCH_LOG"
assert_contains "mecab-0.996.tar.gz" "$FETCH_LOG"
assert_not_contains "open_jtalk_dic_utf_8-1.11.tar.gz" "$FETCH_LOG"
assert_not_contains "MMDAgent_Example-1.8.zip" "$FETCH_LOG"

: >"$FETCH_LOG"
prepare_assets
assert_contains "open_jtalk_dic_utf_8-1.11.tar.gz" "$FETCH_LOG"
assert_contains "MMDAgent_Example-1.8.zip" "$FETCH_LOG"
assert_not_contains "open_jtalk-1.11.tar.gz" "$FETCH_LOG"
assert_not_contains "hts_engine_API-1.10.tar.gz" "$FETCH_LOG"
assert_not_contains "mecab-0.996.tar.gz" "$FETCH_LOG"

# Make requests only the group needed by OPENJTALK_BUNDLE_ASSETS.
make -n -B -C "$ROOT_DIR" \
  MIX_COMPILE_PATH="$TEST_DIR/ebin" \
  OPENJTALK_BUNDLE_ASSETS=0 \
  vendor_ready >"$TEST_DIR/make-no-assets.log"
assert_contains "prepare_vendor.sh\" native" "$TEST_DIR/make-no-assets.log"
assert_not_contains "prepare_vendor.sh\" assets" "$TEST_DIR/make-no-assets.log"

make -n -B -C "$ROOT_DIR" \
  MIX_COMPILE_PATH="$TEST_DIR/ebin" \
  OPENJTALK_BUNDLE_ASSETS=1 \
  vendor_ready >"$TEST_DIR/make-assets.log"
assert_contains "prepare_vendor.sh\" native" "$TEST_DIR/make-assets.log"
assert_contains "prepare_vendor.sh\" assets" "$TEST_DIR/make-assets.log"

log "vendor download tests passed"
