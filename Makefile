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

DIC_TGZ := vendor/open_jtalk_dic_utf_8-1.11.tar.gz
MEI_ZIP := vendor/MMDAgent_Example-1.8.zip

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
EXTRA_CPPFLAGS := -I$(STACK_PREFIX)/include
EXTRA_LDFLAGS  := -L$(STACK_PREFIX)/lib -Wl,-rpath,'$$ORIGIN/../lib' -Wl,-z,origin

# config.sub: repo-local > automake > system
ifeq ($(wildcard $(CURDIR)/config.sub),)
  CONFIG_SUB ?= $(shell automake --print-libdir 2>/dev/null)/config.sub
  ifeq ($(wildcard $(CONFIG_SUB)),)
    CONFIG_SUB := /usr/share/misc/config.sub
  endif
else
  CONFIG_SUB := $(CURDIR)/config.sub
endif

OJT_CFG_STAMP := $(OBJ_DIR)/.ojt_configured-$(HOST_NORM)

# Targets
.PHONY: all ensure_vendor clean distclean dic voice
all: $(PRIV_DIR)/bin/open_jtalk $(PRIV_DIR)/dic/sys.dic $(PRIV_DIR)/voices/mei_normal.htsvoice

dic:   $(PRIV_DIR)/dic/sys.dic
voice: $(PRIV_DIR)/voices/mei_normal.htsvoice

# Fetch (idempotent)
ifeq ($(OPENJTALK_SKIP_FETCH),1)
ensure_vendor:
	@echo "Skipping vendor fetch (OPENJTALK_SKIP_FETCH=1)"
else
ensure_vendor:
	+@ROOT_DIR="$(CURDIR)" /usr/bin/env bash "$(SCRIPT_DIR)/fetch_sources.sh"
endif

# MeCab (static)
$(STACK_PREFIX)/lib/libmecab.a: | ensure_vendor $(STACK_PREFIX)
	+@SRC_DIR="$(MECAB_SRC)" PREFIX="$(STACK_PREFIX)" HOST="$(HOST_NORM)" \
	  CC="$(CC)" CXX="$(CXX)" AR="$(AR)" RANLIB="$(RANLIB)" CONFIG_SUB="$(CONFIG_SUB)" \
	  /usr/bin/env bash "$(SCRIPT_DIR)/build_mecab.sh"

# HTS Engine (static)
$(STACK_PREFIX)/lib/libHTSEngine.a: | ensure_vendor $(STACK_PREFIX)
	+@SRC_DIR="$(HTS_SRC)" PREFIX="$(STACK_PREFIX)" HOST="$(HOST_NORM)" \
	  CC="$(CC)" CXX="$(CXX)" AR="$(AR)" RANLIB="$(RANLIB)" CONFIG_SUB="$(CONFIG_SUB)" \
	  /usr/bin/env bash "$(SCRIPT_DIR)/build_hts_engine.sh"

# Open JTalk configure
$(OJT_CFG_STAMP): $(STACK_PREFIX)/lib/libmecab.a $(STACK_PREFIX)/lib/libHTSEngine.a | ensure_vendor $(OBJ_DIR) $(PRIV_DIR)/bin $(PRIV_DIR)/lib
	+@OJT_DIR=$$( [ -d "$(OJT1)" ] && echo "$(OJT1)" || echo "$(OJT2)" ); \
	  OJT_DIR="$$OJT_DIR" HOST="$(HOST_NORM)" STACK_PREFIX="$(STACK_PREFIX)" OJT_PREFIX="$(OJT_PREFIX)" \
	  CC="$(CC)" CXX="$(CXX)" AR="$(AR)" RANLIB="$(RANLIB)" \
	  EXTRA_CPPFLAGS="$(EXTRA_CPPFLAGS)" EXTRA_LDFLAGS="$(EXTRA_LDFLAGS)" \
	  CONFIG_SUB="$(CONFIG_SUB)" \
	  /usr/bin/env bash "$(SCRIPT_DIR)/ojt_configure.sh"; \
	  touch "$(OJT_CFG_STAMP)"

# Open JTalk build (CLI only)
$(PRIV_DIR)/bin/open_jtalk: $(OJT_CFG_STAMP) | $(PRIV_DIR)/bin
	+@OJT_DIR=$$( [ -d "$(OJT1)" ] && echo "$(OJT1)" || echo "$(OJT2)" ); \
	  OJT_DIR="$$OJT_DIR" DEST_BIN="$(PRIV_DIR)/bin/open_jtalk" STRIP_BIN="$(STRIP)" \
	  CC="$(CC)" CXX="$(CXX)" AR="$(AR)" RANLIB="$(RANLIB)" STACK_PREFIX="$(STACK_PREFIX)" \
	  /usr/bin/env bash "$(SCRIPT_DIR)/ojt_build.sh"

# Dictionary & Voice
$(PRIV_DIR)/dic/sys.dic: | ensure_vendor $(PRIV_DIR)/dic
	+@DIC_TGZ="$(DIC_TGZ)" DEST_DIR="$(PRIV_DIR)/dic" \
	  /usr/bin/env bash "$(SCRIPT_DIR)/install_dic.sh"

$(PRIV_DIR)/voices/mei_normal.htsvoice: | ensure_vendor $(PRIV_DIR)/voices
	+@VOICE_ZIP="$(MEI_ZIP)" DEST_VOICE="$(PRIV_DIR)/voices/mei_normal.htsvoice" \
	  /usr/bin/env bash "$(SCRIPT_DIR)/install_voice.sh"

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
	rm -rf "$(PRIV_DIR)/bin/open_jtalk" "$(PRIV_DIR)/lib" "$(OBJ_DIR)" "$(OJT_CFG_STAMP)"

distclean: clean
	rm -rf "vendor" "$(PRIV_DIR)/dic" "$(PRIV_DIR)/voices"

# Hint for local builds
ifeq ($(strip $(CROSSCOMPILE)),)
  $(warning No cross-compiler detected. Building native code in test mode.)
endif

