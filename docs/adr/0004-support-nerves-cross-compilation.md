# ADR 0004: Support Nerves cross-compilation as a standard build path

## Status

Accepted and implemented. Retrospectively recorded on 2026-10-04.

## Context

Using Japanese speech synthesis on Nerves devices is an important use case for
`open_jtalk_elixir`. In a Nerves build, Mix runs on the host while Open JTalk
must be compiled for the target CPU.

Accidentally reusing host artifacts can produce a successful build containing
an executable that cannot run in the firmware. Open JTalk and its dependencies
also ship old Autotools support files that do not recognize every modern CPU
or Nerves toolchain triplet.

## Decision

Treat builds with `MIX_TARGET` and a cross compiler as part of the standard
native build path.

Honor toolchain programs supplied through `CC`, `CXX`, `AR`, `RANLIB`, and
`STRIP`. Normalize `*-nerves-*` triplets to a form understood by old Autotools
scripts when necessary, and inject the project's pinned `config.sub` and
`config.guess` files into upstream source trees.

Separate build outputs by normalized target triplet. Purge incompatible native
intermediate state when the active triplet changes.

When `MIX_TARGET` is set, request full static linking by default where the
target toolchain supports it. Treat this as a build preference rather than a
guarantee, and allow `OPENJTALK_FULL_STATIC` to override it. Bundle the
dictionary and voice by default, as on host builds, while allowing
`OPENJTALK_BUNDLE_ASSETS=0` for deployments that provision assets separately.

## Consequences

### Benefits

- Nerves applications can consume the library as a normal Mix dependency.
- Host and target builds use the same Elixir API.
- Applications can avoid adding Open JTalk-specific build logic to a Nerves
  System.
- Static linking can reduce target-side shared-library requirements.
- Triplet-specific outputs avoid host and target contamination.
- The default asset policy supports self-contained firmware.

### Costs

- Bundling the dictionary significantly increases firmware size.
- Full static linking depends on target libraries such as static `libstdc++`.
- Compatibility code for old Autotools projects requires maintenance.
- New Nerves targets require validation on real hardware.

## Constraints

- Do not silently use host compilers or libraries for a target build.
- Do not reuse native outputs after the target triplet changes.
- Do not claim that full static linking is guaranteed.
- Preserve the external-asset path for size-constrained firmware.
- Validate synthesis on hardware when adding a Nerves architecture; a
  successful cross-compilation alone is insufficient.

## References

- [Native build entry point](../../Makefile)
- [Open JTalk build script](../../scripts/build_openjtalk.sh)
- [Asset resolution](../../lib/open_jtalk/assets.ex)
- [Project README](../../README.md)
- [ADR 0002](0002-build-native-dependencies-during-package-compilation.md)
- [ADR 0003](0003-resolve-runtime-assets-by-priority.md)
