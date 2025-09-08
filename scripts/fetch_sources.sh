#!/usr/bin/env bash
#
# Download archives to vendor/ and (for sources) extract source trees (idempotent).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ROOT_DIR="${ROOT_DIR:-"$(cd "$SCRIPT_DIR/.." && pwd)"}"
VENDOR="$ROOT_DIR/vendor"
MODE="${1:-all}" # src | assets | all

ensure_tools mkdir curl tar unzip
mkdir -p "$VENDOR" "$ROOT_DIR/priv/dic" "$ROOT_DIR/priv/voices"

# URLs
OPENJTALK_URL="https://sourceforge.net/projects/open-jtalk/files/Open%20JTalk/open_jtalk-1.11/open_jtalk-1.11.tar.gz/download"
HTS_URL="https://sourceforge.net/projects/hts-engine/files/hts_engine%20API/hts_engine_API-1.10/hts_engine_API-1.10.tar.gz/download"
MECAB_URL="https://deb.debian.org/debian/pool/main/m/mecab/mecab_0.996.orig.tar.gz"
DIC_URL="https://sourceforge.net/projects/open-jtalk/files/Dictionary/open_jtalk_dic-1.11/open_jtalk_dic_utf_8-1.11.tar.gz/download"
MEI_URL="https://sourceforge.net/projects/mmdagent/files/MMDAgent_Example/MMDAgent_Example-1.8/MMDAgent_Example-1.8.zip/download"

dl() { # $1=url $2=dest
  local url="$1" dest="$2"
  if [[ -f "$dest" && -s "$dest" ]]; then
    log "already present $(basename "$dest")"
    return 0
  fi
  log "downloading $(basename "$dest")"
  curl -LfsS "$url" -o "$dest" || die "download failed: $url"
}

extract_tgz() { # $1=archive $2=destdir
  local tgz="$1" dest="$2"
  mkdir -p "$dest"
  tar -xzf "$tgz" -C "$dest"
}

if [[ "$MODE" == "src" || "$MODE" == "all" ]]; then
  dl "$OPENJTALK_URL" "$VENDOR/open_jtalk-1.11.tar.gz"
  dl "$HTS_URL" "$VENDOR/hts_engine_API-1.10.tar.gz"
  dl "$MECAB_URL" "$VENDOR/mecab-0.996.tar.gz"

  extract_tgz "$VENDOR/open_jtalk-1.11.tar.gz" "$VENDOR/open_jtalk"
  extract_tgz "$VENDOR/hts_engine_API-1.10.tar.gz" "$VENDOR/hts_engine"
  extract_tgz "$VENDOR/mecab-0.996.tar.gz" "$VENDOR/mecab"

  # Also fetch modern config.sub / config.guess into vendor/ so configure scripts
  # have up-to-date canonicalizers for modern triplets (Raspberry Pi etc.)
  dl 'https://git.savannah.gnu.org/cgit/config.git/plain/config.sub' "$VENDOR/config.sub"
  dl 'https://git.savannah.gnu.org/cgit/config.git/plain/config.guess' "$VENDOR/config.guess"
  chmod +x "$VENDOR/config.sub" "$VENDOR/config.guess"
fi

if [[ "$MODE" == "assets" || "$MODE" == "all" ]]; then
  dl "$DIC_URL" "$VENDOR/open_jtalk_dic_utf_8-1.11.tar.gz"
  dl "$MEI_URL" "$VENDOR/MMDAgent_Example-1.8.zip"
fi

log "fetch ($MODE) done"

