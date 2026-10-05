# Building

The normal `mix compile` flow builds a local Open JTalk executable and, by
default, installs a dictionary and voice under the application `priv/`
directory.

## Requirements

The project supports Elixir 1.15 and later. Native compilation requires:

- `gcc` and `g++`, or the target's compatible C/C++ toolchain;
- `make`;
- `curl`, unless every required archive is already available locally;
- `tar`; and
- `unzip`.

On macOS, Xcode Command Line Tools provide the compiler and `make`.

## First build and downloads

Hex releases do not contain the large upstream source and asset archives. A
first compile normally requires outbound HTTPS access to SourceForge and
Debian mirrors. Pinned `config.sub` and `config.guess` files are included in
the package, so GNU Savannah is not part of the first-build download path.

Every downloaded input is pinned and checked against a SHA-256 digest before
use. Later builds reuse verified archives and native outputs when their inputs
have not changed.

Each required archive is resolved in this order:

1. an existing package-local file under `vendor/`;
2. a same-named file under `OPENJTALK_VENDOR_CACHE`, when configured;
3. a configured mirror; and
4. the archive's built-in upstream sources, in order.

Package-local and cached files are verified before use. A checksum mismatch in
either location fails immediately so a stale or corrupted local input is not
hidden by a network fallback. A failed or checksum-invalid download is rejected
and the next URL is tried. If no candidate succeeds, the error lists the
artifact, cache path, attempted URLs, and expected digest.

Open JTalk and HTS Engine have SourceForge and Debian candidates by default.
Other artifacts retain their authoritative upstream source and can gain an
additional candidate through a mirror or per-artifact URL list.

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
| `OPENJTALK_VENDOR_CACHE` | directory | Read same-named, SHA-256-verified archives from a local cache before using the network |
| `OPENJTALK_VENDOR_MIRROR_URL` | base URL | Try `<base URL>/<archive filename>` before the built-in URLs |

Host builds default to dynamic linking with an executable-relative runtime
library path. Builds with `MIX_TARGET` set request full static linking by
default. Full static linking depends on the selected toolchain, including a
static `libstdc++`, and is not supported for Darwin targets.

### Mirrors and custom URL lists

An internal or project-maintained mirror can be added without changing pinned
versions or digests:

```bash
export OPENJTALK_VENDOR_MIRROR_URL="https://artifacts.example.com/open_jtalk_elixir/vendor-v1"
mix compile
```

For finer control, these variables accept whitespace-separated, ordered URL
lists:

- `OPENJTALK_OPEN_JTALK_URLS`;
- `OPENJTALK_HTS_ENGINE_URLS`;
- `OPENJTALK_MECAB_URLS`;
- `OPENJTALK_DICTIONARY_URLS`; and
- `OPENJTALK_VOICE_URLS`.

When one is set, its list replaces the mirror and built-in URLs for that
artifact. For example:

```bash
export OPENJTALK_MECAB_URLS="https://mirror.example/mecab-0.996.tar.gz https://deb.debian.org/debian/pool/main/m/mecab/mecab_0.996.orig.tar.gz"
```

All candidates must contain the exact pinned bytes; changing a URL does not
change or bypass SHA-256 verification.

### Local cache and offline builds

`OPENJTALK_VENDOR_CACHE` is an explicit input cache. Populate it with files
using these exact names:

```text
open_jtalk-1.11.tar.gz
hts_engine_API-1.10.tar.gz
mecab-0.996.tar.gz
open_jtalk_dic_utf_8-1.11.tar.gz
MMDAgent_Example-1.8.zip
```

Then point the build at it:

```bash
export OPENJTALK_VENDOR_CACHE="$HOME/.cache/open_jtalk_elixir"
mix compile
```

The build copies and verifies cached files; it never silently trusts them. A
fully populated cache permits preparation without outbound access. When
`OPENJTALK_BUNDLE_ASSETS=0`, only the three native source archives are needed,
and the dictionary and MMDAgent archive are neither resolved nor downloaded.
The cache is read-only from the build's perspective, so CI or provisioning
logic remains responsible for populating it.

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
shellcheck -x scripts/*.sh test/scripts/*.sh
bash test/scripts/vendor_download_test.sh
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
