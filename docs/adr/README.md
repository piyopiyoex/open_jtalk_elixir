# Architecture Decision Records

This directory records architectural decisions that are expected to remain
stable in `open_jtalk_elixir`. See the [documentation index](../README.md) for
the role and precedence of each document type.

For usage instructions and the current public API, prefer the
[project README](../../README.md) and module documentation.

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](0001-run-open-jtalk-as-an-external-cli.md) | Run Open JTalk as an external CLI | Accepted and implemented |
| [0002](0002-build-native-dependencies-during-package-compilation.md) | Build native dependencies during package compilation | Accepted and implemented |
| [0003](0003-resolve-runtime-assets-by-priority.md) | Resolve runtime assets by priority | Accepted and implemented |
| [0004](0004-support-nerves-cross-compilation.md) | Support Nerves cross-compilation as a standard build path | Accepted and implemented |

## Maintenance rules

- Record one long-lived decision per ADR.
- State whether a decision is proposed, accepted, rejected, or superseded.
- When a later ADR supersedes all or part of an earlier decision, link the two
  records in both directions.
- When implementation and an ADR diverge, update the record or add a
  superseding ADR.
- Keep operational procedures and temporary investigations out of ADRs.
- Document detailed public API behavior in module documentation or the
  top-level `README.md`.

## Format

```text
# ADR NNNN: Decision title

## Status
## Context
## Decision
## Consequences
### Benefits
### Costs
## Constraints
## References
```
