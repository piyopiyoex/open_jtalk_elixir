#!/usr/bin/env bash
#
# Build MeCab + HTS Engine, configure Open JTalk, and build/install the open_jtalk CLI.
# Idempotent: only builds steps whose expected outputs are missing.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Required (fail early)
: "${MECAB_SRC:?MECAB_SRC must be set}"
: "${HTS_SRC:?HTS_SRC must be set}"
: "${OJT_DIR:?OJT_DIR must be set}"
: "${STACK_PREFIX:?STACK_PREFIX must be set}"
: "${OJT_PREFIX:?OJT_PREFIX must be set}"
: "${HOST:?HOST must be set}"
: "${DEST_BIN:?DEST_BIN must be set}"

# Optional
CC="${CC:-gcc}"
CXX="${CXX:-g++}"
AR="${AR:-ar}"
RANLIB="${RANLIB:-ranlib}"
STRIP_BIN="${STRIP_BIN:-strip}"
CONFIG_SUB="${CONFIG_SUB:-}"
EXTRA_CPPFLAGS="${EXTRA_CPPFLAGS:-}"
EXTRA_LDFLAGS="${EXTRA_LDFLAGS:-}"

ensure_tools make install find

log "build_openjtalk_and_deps -- host=${HOST}"
log "stack prefix: ${STACK_PREFIX}"
log "open_jtalk dst: ${DEST_BIN}"

# Build MeCab if missing
if [[ ! -f "${STACK_PREFIX}/lib/libmecab.a" ]]; then
  log "libmecab.a not found: building MeCab"
  (
    export SRC_DIR="${MECAB_SRC}"
    export PREFIX="${STACK_PREFIX}"
    export HOST="${HOST}"
    export CC="${CC}" CXX="${CXX}" AR="${AR}" RANLIB="${RANLIB}"
    export CONFIG_SUB="${CONFIG_SUB:-}"
    "$SCRIPT_DIR/build_mecab.sh"
  )
else
  log "libmecab.a already present; skipping MeCab build"
fi

# Build HTS Engine if missing
if [[ ! -f "${STACK_PREFIX}/lib/libHTSEngine.a" ]]; then
  log "libHTSEngine.a not found: building HTS Engine"
  (
    export SRC_DIR="${HTS_SRC}"
    export PREFIX="${STACK_PREFIX}"
    export HOST="${HOST}"
    export CC="${CC}" CXX="${CXX}" AR="${AR}" RANLIB="${RANLIB}"
    export CONFIG_SUB="${CONFIG_SUB:-}"
    "$SCRIPT_DIR/build_hts_engine.sh"
  )
else
  log "libHTSEngine.a already present; skipping HTS Engine build"
fi

# Ensure OJT_DIR exists
if [[ ! -d "${OJT_DIR}" ]]; then
  die "Open JTalk source dir not present: ${OJT_DIR}"
fi

# Copy config.sub/config.guess if provided
if [[ -n "${CONFIG_SUB}" && -f "${CONFIG_SUB}" ]]; then
  log "Copying provided config.sub into Open JTalk source tree"
  copy_config_sub_if_present "${CONFIG_SUB}" "${OJT_DIR}"
fi

# Configure Open JTalk (idempotent)
log "Configuring Open JTalk"
(
  export SRC_DIR="${OJT_DIR}"
  export HOST="${HOST}"
  export STACK_PREFIX="${STACK_PREFIX}"
  export PREFIX="${OJT_PREFIX}"
  export CC="${CC}" CXX="${CXX}" AR="${AR}" RANLIB="${RANLIB}"
  export EXTRA_CPPFLAGS="${EXTRA_CPPFLAGS}" EXTRA_LDFLAGS="${EXTRA_LDFLAGS}"
  export CONFIG_SUB="${CONFIG_SUB:-}"
  "$SCRIPT_DIR/configure_openjtalk.sh"
)

# Build & install open_jtalk binary
log "Building & installing open_jtalk"
(
  export SRC_DIR="${OJT_DIR}"
  export DEST_BIN="${DEST_BIN}"
  export STRIP_BIN="${STRIP_BIN}"
  export STACK_PREFIX="${STACK_PREFIX}"
  export CC="${CC}" CXX="${CXX}" AR="${AR}" RANLIB="${RANLIB}"
  "$SCRIPT_DIR/build_openjtalk.sh"
)

log "build_openjtalk_and_deps done"
