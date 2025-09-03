#!/usr/bin/env bash
#
# Download archives to vendor/ and extract source trees (idempotent).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ROOT_DIR="${ROOT_DIR:-"$(cd "$SCRIPT_DIR/.." && pwd)"}"
VENDOR="$ROOT_DIR/vendor"

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

# Download archives
dl "$OPENJTALK_URL" "$VENDOR/open_jtalk-1.11.tar.gz"
dl "$HTS_URL" "$VENDOR/hts_engine_API-1.10.tar.gz"
dl "$MECAB_URL" "$VENDOR/mecab-0.996.tar.gz"
dl "$DIC_URL" "$VENDOR/open_jtalk_dic_utf_8-1.11.tar.gz"
dl "$MEI_URL" "$VENDOR/MMDAgent_Example-1.8.zip"

# Extract source trees (idempotent)
extract_tgz() { # $1=archive $2=destdir
  local tgz="$1" dest="$2"

  mkdir -p "$dest"
  tar -xzf "$tgz" -C "$dest"
}

extract_tgz "$VENDOR/open_jtalk-1.11.tar.gz" "$VENDOR/open_jtalk"
extract_tgz "$VENDOR/hts_engine_API-1.10.tar.gz" "$VENDOR/hts_engine"
extract_tgz "$VENDOR/mecab-0.996.tar.gz" "$VENDOR/mecab"

log "fetch done"
