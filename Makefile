# elixir_make guard
ifeq ($(MIX_COMPILE_PATH),)
  $(error MIX_COMPILE_PATH should be set by elixir_make)
endif

PRIV_DIR   := $(abspath $(MIX_COMPILE_PATH)/../priv)
OBJ_DIR    := $(abspath $(MIX_COMPILE_PATH)/../obj)
SCRIPT_DIR := $(abspath $(CURDIR)/scripts)

# Vendor locations
MECAB_SRC := vendor/mecab/mecab-0.996
HTS_SRC   := vendor/hts_engine/hts_engine_API-1.10
OJT1      := vendor/open_jtalk/open_jtalk-1.11
OJT2      := vendor/open_jtalk-1.11

# Toolchain
CROSSCOMPILE ?=
CC     ?= $(if $(CROSSCOMPILE),$(CROSSCOMPILE)-gcc,gcc)
CXX    ?= $(if $(CROSSCOMPILE),$(CROSSCOMPILE)-g++,g++)
AR     ?= $(if $(CROSSCOMPILE),$(CROSSCOMPILE)-ar,ar)
RANLIB ?= $(if $(CROSSCOMPILE),$(CROSSCOMPILE)-ranlib,ranlib)
STRIP  ?= $(if $(CROSSCOMPILE),$(CROSSCOMPILE)-strip,strip)

# Derive CROSSCOMPILE from CC if needed
CC_BASENAME := $(notdir $(CC))
CC_PREFIX   := $(patsubst %-gcc,%,$(CC_BASENAME))
ifeq ($(strip $(CROSSCOMPILE)),)
  ifneq ($(CC_PREFIX),$(CC_BASENAME))
    CROSSCOMPILE := $(CC_PREFIX)
  endif
endif

# Host triplet (normalize *-nerves-* -> *-unknown-* for older config.sub)
HOST_RAW  := $(shell $(CC) -dumpmachine 2>/dev/null)
HOST_NORM := $(shell printf '%s' '$(HOST_RAW)' | sed -E 's/-nerves-/-unknown-/')

# Per-triplet output
STACK_PREFIX := $(abspath $(OBJ_DIR)/stack-$(HOST_NORM))
OJT_PREFIX   := $(abspath $(OBJ_DIR)/open_jtalk-$(HOST_NORM))

# Flags
DEFAULT_CPPFLAGS := -I$(STACK_PREFIX)/include
EXTRA_CPPFLAGS ?= $(DEFAULT_CPPFLAGS)

# Host OS name (for RPATH flags)
UNAME_S := $(shell uname -s)

# OPENJTALK_FULL_STATIC defaults to 1 when MIX_TARGET is set (Nerves), otherwise 0.
# Users can still override by exporting the env var.
OPENJTALK_FULL_STATIC ?= $(if $(strip $(MIX_TARGET)),1,0)

# Disallow static for *darwin* targets (static linking not supported there).
ifneq (,$(findstring darwin,$(HOST_NORM)))
  ifeq ($(OPENJTALK_FULL_STATIC),1)
    $(error OPENJTALK_FULL_STATIC=1 is not supported for darwin targets)
  endif
endif

ifeq ($(UNAME_S),Darwin)
  # macOS uses @loader_path for rpath
  RPATH_FLAGS = -Wl,-rpath,@loader_path/../lib
else
  # Linux/BSD: $ORIGIN + mark origin
  RPATH_FLAGS = -Wl,-rpath,'$$ORIGIN/../lib' -Wl,-z,origin
endif

ifeq ($(OPENJTALK_FULL_STATIC),1)
  DEFAULT_LDFLAGS := -L$(STACK_PREFIX)/lib -static -static-libgcc -static-libstdc++
else
  DEFAULT_LDFLAGS := -L$(STACK_PREFIX)/lib $(RPATH_FLAGS)
endif
EXTRA_LDFLAGS ?= $(DEFAULT_LDFLAGS)

# Whether to bundle dictionary/voices into priv/ (1=yes, 0=no).
# Default ON for an “it just works” experience; CI/users can opt out via env.
OPENJTALK_BUNDLE_ASSETS ?= 1

# config.sub: prefer env CONFIG_SUB -> repo-local -> vendor -> automake -> system
ifneq ($(wildcard $(CONFIG_SUB)),)
  CONFIG_SUB := $(CONFIG_SUB)
else ifneq ($(wildcard $(CURDIR)/config.sub),)
  CONFIG_SUB := $(CURDIR)/config.sub
else ifneq ($(wildcard $(CURDIR)/vendor/config.sub),)
  CONFIG_SUB := $(CURDIR)/vendor/config.sub
else
  CONFIG_SUB := $(shell automake --print-libdir 2>/dev/null)/config.sub
  ifeq ($(wildcard $(CONFIG_SUB)),)
    CONFIG_SUB := /usr/share/misc/config.sub
  endif
endif

# Elixir runner
ELIXIR ?= elixir
FETCH_EXS := $(SCRIPT_DIR)/fetch_sources.exs
FETCH_JOBS ?= $(shell $(ELIXIR) -e 'IO.puts(System.schedulers_online()*2)')
FETCH_RETRIES ?= 3
FETCH_VERBOSE ?= 1

# ------------------------------------------------------------------------------
# Targets
# ------------------------------------------------------------------------------
.PHONY: all dic voice ensure_src ensure_assets clean distclean show-config-sub

ifeq ($(OPENJTALK_BUNDLE_ASSETS),1)
all: $(PRIV_DIR)/bin/open_jtalk $(PRIV_DIR)/dic/sys.dic $(PRIV_DIR)/voices/mei_normal.htsvoice
else
all: $(PRIV_DIR)/bin/open_jtalk
endif

dic:   $(PRIV_DIR)/dic/sys.dic
voice: $(PRIV_DIR)/voices/mei_normal.htsvoice

# Fetchers (idempotent)
ensure_src:
	+@OPENJTALK_ROOT_DIR="$(CURDIR)" \
	   OPENJTALK_FETCH_JOBS="$(FETCH_JOBS)" \
	   OPENJTALK_FETCH_RETRIES="$(FETCH_RETRIES)" \
	   OPENJTALK_FETCH_VERBOSE="$(FETCH_VERBOSE)" \
	   $(ELIXIR) "$(FETCH_EXS)" src

ifeq ($(OPENJTALK_BUNDLE_ASSETS),1)
ensure_assets:
	+@OPENJTALK_ROOT_DIR="$(CURDIR)" \
	   OPENJTALK_FETCH_JOBS="$(FETCH_JOBS)" \
	   OPENJTALK_FETCH_RETRIES="$(FETCH_RETRIES)" \
	   OPENJTALK_FETCH_VERBOSE="$(FETCH_VERBOSE)" \
	   $(ELIXIR) "$(FETCH_EXS)" assets
else
ensure_assets:
	@echo "Skipping asset download (OPENJTALK_BUNDLE_ASSETS=0)"
endif

show-config-sub:
	@printf "CONFIG_SUB = %s\n" "$(CONFIG_SUB)"

# Build stack and open_jtalk directly (no stamp)
$(PRIV_DIR)/bin/open_jtalk: | ensure_src $(OBJ_DIR) $(PRIV_DIR)/bin $(PRIV_DIR)/lib
	+@OJT_DIR=$$( [ -d "$(OJT1)" ] && echo "$(OJT1)" || echo "$(OJT2)" ); \
	  echo "Building stack and Open JTalk (OJT_DIR=$$OJT_DIR)"; \
	  MECAB_SRC="$(MECAB_SRC)" HTS_SRC="$(HTS_SRC)" OJT_DIR="$$OJT_DIR" \
	  STACK_PREFIX="$(STACK_PREFIX)" OJT_PREFIX="$(OJT_PREFIX)" HOST="$(HOST_NORM)" \
	  CC="$(CC)" CXX="$(CXX)" AR="$(AR)" RANLIB="$(RANLIB)" STRIP_BIN="$(STRIP)" \
	  CONFIG_SUB="$(CONFIG_SUB)" EXTRA_CPPFLAGS="$(EXTRA_CPPFLAGS)" EXTRA_LDFLAGS="$(EXTRA_LDFLAGS)" \
	  DEST_BIN="$(PRIV_DIR)/bin/open_jtalk" \
	  /usr/bin/env bash "$(SCRIPT_DIR)/build_openjtalk_and_deps.sh"

# Dictionary & Voice (no-op; installed by ensure_assets)
$(PRIV_DIR)/dic/sys.dic: | ensure_assets $(PRIV_DIR)/dic
	@true

$(PRIV_DIR)/voices/mei_normal.htsvoice: | ensure_assets $(PRIV_DIR)/voices
	@true

# Dirs
$(OBJ_DIR) \
$(STACK_PREFIX) \
$(PRIV_DIR) \
$(PRIV_DIR)/bin \
$(PRIV_DIR)/lib \
$(PRIV_DIR)/dic \
$(PRIV_DIR)/voices:
	mkdir -p "$@"

# Clean
clean:
	rm -rf "$(PRIV_DIR)/bin/open_jtalk" "$(PRIV_DIR)/lib" "$(OBJ_DIR)"

distclean: clean
	rm -rf "vendor" "$(PRIV_DIR)/dic" "$(PRIV_DIR)/voices"

# Hint for local builds
ifeq ($(strip $(CROSSCOMPILE)),)
  $(warning No cross-compiler detected. Building native code in test mode.)
endif

