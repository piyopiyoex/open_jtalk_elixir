#!/usr/bin/env bash
#
# Build MeCab + HTS Engine, configure Open JTalk, and build/install the open_jtalk CLI.
# Idempotent: only builds steps whose expected outputs are missing.
#
# Expects certain environment variables to be provided by the Makefile invocation:
#   MECAB_SRC, HTS_SRC, OJT_DIR, STACK_PREFIX, OJT_PREFIX, HOST
#   CC, CXX, AR, RANLIB, STRIP_BIN, DEST_BIN
#   CONFIG_SUB (optional)
#   EXTRA_CPPFLAGS, EXTRA_LDFLAGS (optional)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Required vars (fail early with a friendly message)
: "${MECAB_SRC:?MECAB_SRC must be set}"
: "${HTS_SRC:?HTS_SRC must be set}"
: "${OJT_DIR:?OJT_DIR must be set}"
: "${STACK_PREFIX:?STACK_PREFIX must be set}"
: "${OJT_PREFIX:?OJT_PREFIX must be set}"
: "${HOST:?HOST must be set}"
: "${CC:-gcc}"
: "${CXX:-g++}"
: "${AR:-ar}"
: "${RANLIB:-ranlib}"
: "${DEST_BIN:?DEST_BIN must be set}"

# Optional
CONFIG_SUB="${CONFIG_SUB:-}"
EXTRA_CPPFLAGS="${EXTRA_CPPFLAGS:-}"
EXTRA_LDFLAGS="${EXTRA_LDFLAGS:-}"
STRIP_BIN="${STRIP_BIN:-strip}"

# Make sure basic tools are present
ensure_tools make install find

log "build_stack_and_openjtalk -- host=${HOST}"
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

# Configure Open JTalk (idempotent step: configure may be re-run harmlessly)
log "Configuring Open JTalk"
(
  export OJT_DIR="${OJT_DIR}"
  export HOST="${HOST}"
  export STACK_PREFIX="${STACK_PREFIX}"
  export OJT_PREFIX="${OJT_PREFIX}"
  export CC="${CC}" CXX="${CXX}" AR="${AR}" RANLIB="${RANLIB}"
  export EXTRA_CPPFLAGS="${EXTRA_CPPFLAGS}" EXTRA_LDFLAGS="${EXTRA_LDFLAGS}"
  export CONFIG_SUB="${CONFIG_SUB:-}"
  "$SCRIPT_DIR/ojt_configure.sh"
)

# Build & install open_jtalk binary
log "Building & installing open_jtalk"
(
  export OJT_DIR="${OJT_DIR}"
  export DEST_BIN="${DEST_BIN}"
  export STRIP_BIN="${STRIP_BIN}"
  export STACK_PREFIX="${STACK_PREFIX}"
  export CC="${CC}" CXX="${CXX}" AR="${AR}" RANLIB="${RANLIB}"
  "$SCRIPT_DIR/ojt_build.sh"
)

log "build_stack_and_openjtalk done"
