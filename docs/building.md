# Building

The normal `mix compile` flow builds a local Open JTalk executable and, by
default, installs a dictionary and voice under the application `priv/`
directory.

## Requirements

The project supports Elixir 1.15 and later. Native compilation requires:

- `gcc` and `g++`, or the target's compatible C/C++ toolchain;
- `make`;
- `curl`;
- `tar`; and
- `unzip`.

On macOS, Xcode Command Line Tools provide the compiler and `make`.

## First build and downloads

Hex releases do not contain the large upstream source and asset archives. A
first compile normally requires outbound HTTPS access to SourceForge, Debian
mirrors, and GNU Savannah.

Every downloaded input is pinned and checked against a SHA-256 digest before
use. Later builds reuse verified archives and native outputs when their inputs
have not changed.

## Build flow

`elixir_make` invokes the repository `Makefile`, which coordinates the native
build:

```text
mix compile
  -> elixir_make
  -> Makefile
  -> scripts/prepare_vendor.sh
  -> scripts/build_openjtalk.sh
  -> priv/bin/open_jtalk
```

The build compiles MeCab 0.996, HTS Engine API 1.10, and Open JTalk 1.11.
Extracted sources and Autotools-generated files stay under
`_build/.../obj/vendor/`, separate from downloaded inputs in `vendor/`.

Native outputs are separated by target triplet. Changing the triplet discards
incompatible intermediate state rather than reusing host or another target's
objects.

## Build options

| Environment variable | Values | Behavior |
| --- | --- | --- |
| `OPENJTALK_BUNDLE_ASSETS` | `0` or `1` | Bundle the dictionary and voice; default `1` |
| `OPENJTALK_FULL_STATIC` | `0` or `1` | Request fully static CLI linking on Linux targets |

Host builds default to dynamic linking with an executable-relative runtime
library path. Builds with `MIX_TARGET` set request full static linking by
default. Full static linking depends on the selected toolchain, including a
static `libstdc++`, and is not supported for Darwin targets.

## Runtime outputs

Compilation installs:

- `priv/bin/open_jtalk`;
- `priv/lib/` when runtime libraries are needed;
- `priv/dictionary/sys.dic` when assets are bundled; and
- `priv/voices/mei_normal.htsvoice` when assets are bundled.

Removing `_build` resets generated native state. `mix clean` invokes the
project's native clean target for the active build.

## Tested combinations

CI covers:

- Elixir 1.15 / OTP 26 on Linux x86_64;
- Elixir 1.19 / OTP 28 on Linux x86_64 and aarch64;
- Elixir 1.19 / OTP 28 on macOS 14 arm64; and
- an aarch64 RPi 4 cross-build.

Other compatible Elixir, OTP, OS, and target combinations may work but are not
part of the CI matrix.

## Development checks

Run the same checks used by CI before submitting changes:

```bash
mix format --check-formatted
shellcheck -x scripts/*.sh
MIX_ENV=lint mix compile --warnings-as-errors
MIX_ENV=lint mix dialyzer --format short
MIX_ENV=lint mix credo --all --strict --format=oneline
mix test
```

Audio playback tests are excluded by default because they require a supported
system player. Enable them with:

```bash
OPENJTALK_AUDIO_TESTS=1 mix test
```

Maintainers should also follow the repository-only
[release checklist](https://github.com/piyopiyoex/open_jtalk_elixir/blob/main/RELEASE.md)
when publishing a package.
