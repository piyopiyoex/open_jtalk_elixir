# ADR 0002: Build native dependencies during package compilation

## Status

Accepted and implemented. Retrospectively recorded on 2026-10-04.

## Context

Open JTalk requires Open JTalk itself, MeCab, and HTS Engine API. Requiring
users to install each dependency as a system package would expose differences
between Linux distributions, macOS, CPU architectures, and Nerves toolchains.

Shipping prebuilt binaries for selected environments would instead require the
project to maintain an expanding platform and ABI matrix.

## Decision

Use `elixir_make` to invoke the repository `Makefile`, and build Open JTalk and
its native dependencies as part of package compilation.

Pin the upstream versions and verify every downloaded source or asset archive
against a SHA-256 digest before use. The currently pinned native versions are:

- Open JTalk 1.11;
- HTS Engine API 1.10; and
- MeCab 0.996.

Install the resulting executable at `priv/bin/open_jtalk`. Extract upstream
sources and place Autotools-generated files under `_build/.../obj/`, not in the
repository source tree. Separate native outputs by target triplet and discard
incompatible intermediate state when the triplet changes.

Do not include the large upstream archives in the Hex package. Download any
missing archives during the first build and reuse verified local archives and
build outputs on subsequent builds.

## Consequences

### Benefits

- Users do not need to install Open JTalk, MeCab, and HTS Engine separately.
- The project controls the upstream versions used by the build.
- SHA-256 verification protects the integrity of downloaded inputs.
- Host builds and cross-compilation use the same build flow.
- Compatibility handling for old Autotools projects stays inside this
  package.
- Removing `_build` resets generated native state.

### Costs

- A first build may require a C/C++ toolchain and outbound network access.
- Compilation takes longer than a pure Elixir package.
- The project must maintain compatibility with old upstream build systems.
- A first build fails when required download sources are unavailable.

## Constraints

- Update the corresponding SHA-256 digest whenever an upstream input changes.
- Do not treat extracted upstream source as repository source.
- Do not share host-specific and target-specific native outputs.
- Keep compatibility handling for old `config.sub` and `config.guess` files
  explicit.
- Record a separate ADR before switching to distributed prebuilt binaries.

## References

- [Mix project configuration](../../mix.exs)
- [Native build entry point](../../Makefile)
- [Vendor preparation](../../scripts/prepare_vendor.sh)
- [Open JTalk build script](../../scripts/build_openjtalk.sh)
