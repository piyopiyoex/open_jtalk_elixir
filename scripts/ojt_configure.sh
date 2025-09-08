#!/usr/bin/env bash
#
# Run Open JTalk ./configure using stack paths; do not build.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ensure_tools make

: "${OJT_DIR:?set OJT_DIR}"
: "${HOST:?set HOST}"
: "${STACK_PREFIX:?set STACK_PREFIX}"
: "${OJT_PREFIX:?set OJT_PREFIX}"

CC="${CC:-gcc}"; CXX="${CXX:-g++}"; AR="${AR:-ar}"; RANLIB="${RANLIB:-ranlib}"
EXTRA_CPPFLAGS="${EXTRA_CPPFLAGS:-}"
EXTRA_LDFLAGS="${EXTRA_LDFLAGS:-}"
CONFIG_SUB="${CONFIG_SUB:-}"
CONFIG_GUESS="${CONFIG_GUESS:-}"
BUILD_TRIPLET="${BUILD_TRIPLET:-}"

log "OpenJTalk dir: $OJT_DIR"
log "OpenJTalk --host=$HOST"

if [[ -f "$OJT_DIR/Makefile" ]]; then
  make -C "$OJT_DIR" distclean || make -C "$OJT_DIR" clean || true
fi
find "$OJT_DIR" -type f \( -name '*.o' -o -name '*.lo' -o -name '*.la' \) -delete || true
copy_config_sub_if_present "$CONFIG_SUB" "$OJT_DIR"
copy_config_guess_if_present "$CONFIG_GUESS" "$OJT_DIR"

( cd "$OJT_DIR"
  env LC_ALL=C PATH="$STACK_PREFIX/bin:$PATH" \
      MECAB_CONFIG="$STACK_PREFIX/bin/mecab-config" \
      CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" \
      CPPFLAGS="$EXTRA_CPPFLAGS" \
      LDFLAGS="$EXTRA_LDFLAGS" \
    ./configure \
      --prefix="$OJT_PREFIX" \
      --with-hts-engine-header-path="$STACK_PREFIX/include" \
      --with-hts-engine-library-path="$STACK_PREFIX/lib" \
      --host="$HOST" ${BUILD_TRIPLET:+--build="$BUILD_TRIPLET"}
)
