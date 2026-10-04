# Architecture Decision Records

This directory records architectural decisions that are expected to remain
stable in `open_jtalk_elixir`.

For usage instructions and the current public API, prefer the repository's
top-level `README.md` and module documentation.

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](0001-run-open-jtalk-as-an-external-cli.md) | Run Open JTalk as an external CLI | Accepted and implemented |
| [0002](0002-build-native-dependencies-during-package-compilation.md) | Build native dependencies during package compilation | Accepted and implemented |
| [0003](0003-resolve-runtime-assets-by-priority.md) | Resolve runtime assets by priority | Accepted and implemented |
| [0004](0004-support-nerves-cross-compilation.md) | Support Nerves cross-compilation as a standard build path | Accepted and implemented |

## Maintenance rules

- Record one long-lived decision per ADR.
- State whether a decision is proposed, accepted, rejected, or superseded.
- When implementation and an ADR diverge, update the ADR or add a superseding
  ADR.
- Keep operational procedures and temporary investigations out of ADRs.
- Document detailed public API behavior in module documentation or the
  top-level `README.md`.
