#!/usr/bin/env bash
#
# Prepare vendor/ with pinned source + asset archives and gnuconfig scripts.
# Usage:
#   scripts/prepare_vendor.sh         # download anything missing
#   scripts/prepare_vendor.sh --force # re-download everything
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/common.sh"

main() {
  # Force toggle
  # shellcheck disable=SC2034 # Read by fetch() from sourced common.sh.
  if [[ "${1:-}" == "--force" ]]; then FORCE=1; else FORCE=0; fi

  ensure_tools awk curl mkdir mv

  # Repo root = script's parent dir
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
  VENDOR_DIR="$ROOT_DIR/vendor"

  # Layout we’re ensuring:
  # vendor/
  # ├── config/{config.guess,config.sub}
  # ├── hts_engine_API-1.10.tar.gz
  # ├── mecab-0.996.tar.gz
  # ├── MMDAgent_Example-1.8.zip
  # ├── open_jtalk-1.11.tar.gz
  # └── open_jtalk_dic_utf_8-1.11.tar.gz
  mkdir -p "$VENDOR_DIR/config"

  # 1) gnuconfig
  fetch "https://gitweb.git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;h=3d35cde174de9cd9788e4bff9b5391c1b06a2fbe" \
    "$VENDOR_DIR/config/config.sub" \
    "26b852f75a637448360a956931439f7e818bf63150eaadb9b85484347628d1fd" true
  fetch "https://gitweb.git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;h=a9d01fde461761d5843d56cb11e1a7156ddfe977" \
    "$VENDOR_DIR/config/config.guess" \
    "50205cf3ec5c7615b17f937a0a57babf4ec5cd0aade3d7b3cccbe5f1bf91a7ef" true

  # 2) sources
  fetch "https://sourceforge.net/projects/open-jtalk/files/Open%20JTalk/open_jtalk-1.11/open_jtalk-1.11.tar.gz/download" \
    "$VENDOR_DIR/open_jtalk-1.11.tar.gz" \
    "20fdc6aeb6c757866034abc175820573db43e4284707c866fcd02c8ec18de71f"
  fetch "https://sourceforge.net/projects/hts-engine/files/hts_engine%20API/hts_engine_API-1.10/hts_engine_API-1.10.tar.gz/download" \
    "$VENDOR_DIR/hts_engine_API-1.10.tar.gz" \
    "e2132be5860d8fb4a460be766454cfd7c3e21cf67b509c48e1804feab14968f7"
  fetch "https://deb.debian.org/debian/pool/main/m/mecab/mecab_0.996.orig.tar.gz" \
    "$VENDOR_DIR/mecab-0.996.tar.gz" \
    "e073325783135b72e666145c781bb48fada583d5224fb2490fb6c1403ba69c59"

  # 3) assets
  fetch "https://sourceforge.net/projects/open-jtalk/files/Dictionary/open_jtalk_dic-1.11/open_jtalk_dic_utf_8-1.11.tar.gz/download" \
    "$VENDOR_DIR/open_jtalk_dic_utf_8-1.11.tar.gz" \
    "33e9cd251bc41aa2bd7ca36f57abbf61eae3543ca25ca892ae345e394cb10549"
  fetch "https://sourceforge.net/projects/mmdagent/files/MMDAgent_Example/MMDAgent_Example-1.8/MMDAgent_Example-1.8.zip/download" \
    "$VENDOR_DIR/MMDAgent_Example-1.8.zip" \
    "f702f2109a07dca103c7b9a5123a25c6dda038f0d7fcc899ff0281d07e873a63"

  log "done. vendor prepared at: $VENDOR_DIR"
}

main "$@"
