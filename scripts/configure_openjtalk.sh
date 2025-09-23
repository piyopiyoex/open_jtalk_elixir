#!/usr/bin/env bash
#
# Run Open JTalk ./configure using stack paths; do not build.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ensure_tools make

: "${SRC_DIR:?set SRC_DIR}"
: "${HOST:?set HOST}"
: "${STACK_PREFIX:?set STACK_PREFIX}"
: "${PREFIX:?set PREFIX}" 

CC="${CC:-gcc}"
CXX="${CXX:-g++}"
AR="${AR:-ar}"
RANLIB="${RANLIB:-ranlib}"
EXTRA_CPPFLAGS="${EXTRA_CPPFLAGS:-}"
EXTRA_LDFLAGS="${EXTRA_LDFLAGS:-}"
CONFIG_SUB="${CONFIG_SUB:-}"

log "OpenJTalk dir: $SRC_DIR"
log "OpenJTalk --host=$HOST"

if [[ -n "${CONFIG_SUB}" && -f "${CONFIG_SUB}" ]]; then
  log "Using provided config.sub: $(basename "${CONFIG_SUB}")"
fi

if [[ -f "${CONFIG_SUB}" ]]; then
  copy_config_sub_if_present "${CONFIG_SUB}" "${SRC_DIR}"
fi

(
  cd "$SRC_DIR"
  env LC_ALL=C PATH="$STACK_PREFIX/bin:$PATH" \
    MECAB_CONFIG="$STACK_PREFIX/bin/mecab-config" \
    CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" \
    CPPFLAGS="$EXTRA_CPPFLAGS" \
    LDFLAGS="$EXTRA_LDFLAGS" \
    ./configure \
    --prefix="$PREFIX" \
    --with-hts-engine-header-path="$STACK_PREFIX/include" \
    --with-hts-engine-library-path="$STACK_PREFIX/lib" \
    --host="$HOST"
)
