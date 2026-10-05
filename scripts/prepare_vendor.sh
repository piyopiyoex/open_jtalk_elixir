#!/usr/bin/env bash
#
# Prepare vendor/ with pinned source and asset archives.
# Usage:
#   scripts/prepare_vendor.sh [all|native|assets] [--force]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/common.sh"

ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/vendor"

append_urls() {
  local value="$1" candidate
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] && FETCH_URLS+=("$candidate")
  done < <(printf '%s\n' "$value" | awk '{ for (i = 1; i <= NF; i++) print $i }')
}

fetch_artifact() {
  local filename="$1" expected_sha256="$2" urls_variable="$3"
  shift 3
  local configured_urls="${!urls_variable:-}"
  # shellcheck disable=SC2034 # Populated by append_urls.
  FETCH_URLS=()

  if [[ -n "$configured_urls" ]]; then
    append_urls "$configured_urls"
  else
    if [[ -n "${OPENJTALK_VENDOR_MIRROR_URL:-}" ]]; then
      FETCH_URLS+=("${OPENJTALK_VENDOR_MIRROR_URL%/}/$filename")
    fi
    FETCH_URLS+=("$@")
  fi

  fetch "$VENDOR_DIR/$filename" "$expected_sha256" false "${FETCH_URLS[@]}"
}

prepare_native_sources() {
  fetch_artifact \
    "open_jtalk-1.11.tar.gz" \
    "20fdc6aeb6c757866034abc175820573db43e4284707c866fcd02c8ec18de71f" \
    "OPENJTALK_OPEN_JTALK_URLS" \
    "https://sourceforge.net/projects/open-jtalk/files/Open%20JTalk/open_jtalk-1.11/open_jtalk-1.11.tar.gz/download" \
    "https://deb.debian.org/debian/pool/main/o/open-jtalk/open-jtalk_1.11.orig.tar.gz"
  fetch_artifact \
    "hts_engine_API-1.10.tar.gz" \
    "e2132be5860d8fb4a460be766454cfd7c3e21cf67b509c48e1804feab14968f7" \
    "OPENJTALK_HTS_ENGINE_URLS" \
    "https://sourceforge.net/projects/hts-engine/files/hts_engine%20API/hts_engine_API-1.10/hts_engine_API-1.10.tar.gz/download" \
    "https://deb.debian.org/debian/pool/main/h/htsengine/htsengine_1.10.orig.tar.gz"
  fetch_artifact \
    "mecab-0.996.tar.gz" \
    "e073325783135b72e666145c781bb48fada583d5224fb2490fb6c1403ba69c59" \
    "OPENJTALK_MECAB_URLS" \
    "https://deb.debian.org/debian/pool/main/m/mecab/mecab_0.996.orig.tar.gz"
}

prepare_assets() {
  fetch_artifact \
    "open_jtalk_dic_utf_8-1.11.tar.gz" \
    "33e9cd251bc41aa2bd7ca36f57abbf61eae3543ca25ca892ae345e394cb10549" \
    "OPENJTALK_DICTIONARY_URLS" \
    "https://sourceforge.net/projects/open-jtalk/files/Dictionary/open_jtalk_dic-1.11/open_jtalk_dic_utf_8-1.11.tar.gz/download"
  fetch_artifact \
    "MMDAgent_Example-1.8.zip" \
    "f702f2109a07dca103c7b9a5123a25c6dda038f0d7fcc899ff0281d07e873a63" \
    "OPENJTALK_VOICE_URLS" \
    "https://sourceforge.net/projects/mmdagent/files/MMDAgent_Example/MMDAgent_Example-1.8/MMDAgent_Example-1.8.zip/download"
}

usage() {
  printf '%s\n' "Usage: $0 [all|native|assets] [--force]" >&2
}

main() {
  local mode="all" argument
  # shellcheck disable=SC2034 # Read by fetch() from sourced common.sh.
  FORCE=0

  for argument in "$@"; do
    case "$argument" in
      all|native|assets) mode="$argument" ;;
      --force) FORCE=1 ;;
      -h|--help) usage; return 0 ;;
      *) usage; die "Unknown argument: $argument" ;;
    esac
  done

  ensure_tools awk cp mkdir mv

  # Layout we’re ensuring:
  # vendor/
  # ├── config/{config.guess,config.sub}
  # ├── hts_engine_API-1.10.tar.gz
  # ├── mecab-0.996.tar.gz
  # ├── MMDAgent_Example-1.8.zip
  # ├── open_jtalk-1.11.tar.gz
  # └── open_jtalk_dic_utf_8-1.11.tar.gz
  mkdir -p "$VENDOR_DIR"

  case "$mode" in
    native) prepare_native_sources ;;
    assets) prepare_assets ;;
    all)
      prepare_native_sources
      prepare_assets
      ;;
  esac

  log "done. $mode vendor inputs prepared at: $VENDOR_DIR"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
