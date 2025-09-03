#!/usr/bin/env bash
#
# Build the open_jtalk CLI and install it to DEST_BIN.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ensure_tools make install find

: "${OJT_DIR:?set OJT_DIR}"
: "${DEST_BIN:?set DEST_BIN}"

CC="${CC:-gcc}"; CXX="${CXX:-g++}"; AR="${AR:-ar}"; RANLIB="${RANLIB:-ranlib}"
STRIP_BIN="${STRIP_BIN:-strip}"
STACK_PREFIX="${STACK_PREFIX:-}"

if [[ -d "$OJT_DIR/src" ]]; then
  log "Building in $OJT_DIR/src"
  env LC_ALL=C PATH="$STACK_PREFIX/bin:$PATH" MECAB_CONFIG="$STACK_PREFIX/bin/mecab-config" \
      CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" \
    make -C "$OJT_DIR/src" open_jtalk
  SRC_BIN="$OJT_DIR/src/open_jtalk"
else
  log "Building at $OJT_DIR"
  set +e
  env LC_ALL=C PATH="$STACK_PREFIX/bin:$PATH" MECAB_CONFIG="$STACK_PREFIX/bin/mecab-config" \
      CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" \
    make -C "$OJT_DIR" open_jtalk
  rc=$?
  if [[ $rc -ne 0 ]]; then
    env LC_ALL=C PATH="$STACK_PREFIX/bin:$PATH" MECAB_CONFIG="$STACK_PREFIX/bin/mecab-config" \
        CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" \
      make -C "$OJT_DIR" all
  fi
  set -e
  SRC_BIN="$(find "$OJT_DIR" -maxdepth 2 -type f -name open_jtalk -perm -u+x | head -n1)"
fi

[[ -n "${SRC_BIN:-}" && -f "$SRC_BIN" ]] || die "open_jtalk binary not produced"
install -m 0755 -D "$SRC_BIN" "$DEST_BIN"
"$STRIP_BIN" "$DEST_BIN" || true
