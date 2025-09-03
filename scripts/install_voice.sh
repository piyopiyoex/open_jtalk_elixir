#!/usr/bin/env bash
#
# Extract the Mei voice from the zip and install it to DEST_VOICE.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ensure_tools unzip mktemp find

: "${VOICE_ZIP:?set VOICE_ZIP}"
: "${DEST_VOICE:?set DEST_VOICE}"

tmpv="$(mktemp -d)"
trap 'rm -rf "$tmpv"' EXIT

unzip -q -o "$VOICE_ZIP" -d "$tmpv"

candidate="$tmpv/MMDAgent_Example-1.8/Voice/mei/mei_normal.htsvoice"
if [[ -f "$candidate" ]]; then
  src="$candidate"
else
  src="$(find "$tmpv" -name 'mei_normal.htsvoice' -print -quit || true)"
fi
[[ -n "$src" && -f "$src" ]] || die "mei_normal.htsvoice not found in zip"

mkdir -p "$(dirname "$DEST_VOICE")"
cp -f "$src" "$DEST_VOICE"
