#!/usr/bin/env bash
#
# Configure & build static MeCab into PREFIX for HOST.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ensure_tools make sed awk

: "${SRC_DIR:?set SRC_DIR}"
: "${PREFIX:?set PREFIX}"
: "${HOST:?set HOST}"

CC="${CC:-gcc}"
CXX="${CXX:-g++}"
AR="${AR:-ar}"
RANLIB="${RANLIB:-ranlib}"
CONFIG_SUB="${CONFIG_SUB:-}"

log "MeCab --host=$HOST"
if [[ -f "$SRC_DIR/Makefile" ]]; then
  make -C "$SRC_DIR" distclean || make -C "$SRC_DIR" clean || true
fi
find "$SRC_DIR" -type f \( -name '*.o' -o -name '*.lo' -o -name '*.la' \) -delete || true
copy_config_sub_if_present "$CONFIG_SUB" "$SRC_DIR"

(
  cd "$SRC_DIR"
  env LC_ALL=C CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" \
    ./configure \
    --prefix="$PREFIX" \
    --with-charset=utf8 \
    --enable-static --disable-shared \
    --host="$HOST"
)

make -C "$SRC_DIR" CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB"
make -C "$SRC_DIR" install CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB"

test -f "$PREFIX/lib/libmecab.a" || die "libmecab.a not found"
