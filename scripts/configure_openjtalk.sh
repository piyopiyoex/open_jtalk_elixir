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
# CONFIG_SUB may be set by the Makefile (we prefer repo-local / vendor copies)

log "OpenJTalk dir: $OJT_DIR"
log "OpenJTalk --host=$HOST"

# Helpful debug info to show which config.sub is being used (useful in CI logs)
if [[ -n "${CONFIG_SUB}" && -f "${CONFIG_SUB}" ]]; then
  log "CONFIG_SUB (provided) = ${CONFIG_SUB}"
else
  log "CONFIG_SUB not provided or missing; falling back to system config.sub"
fi

if [[ -f "${CONFIG_SUB}" ]]; then
  # show a concise confirmation for logs
  log "Using provided config.sub: $(basename "${CONFIG_SUB}")"
fi

if [[ -f "$OJT_DIR/config.sub" || -f "$OJT_DIR/config/config.sub" ]]; then
  log "Target tree already contains config.sub: $( [ -f \"$OJT_DIR/config.sub\" ] && echo \"$OJT_DIR/config.sub\" || true ) $( [ -f \"$OJT_DIR/config/config.sub\" ] && echo \"$OJT_DIR/config/config.sub\" || true )"
fi

if [[ -f "${CONFIG_SUB}" ]]; then
  copy_config_sub_if_present "${CONFIG_SUB}" "${OJT_DIR}"
fi

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
      --host="$HOST"
)

