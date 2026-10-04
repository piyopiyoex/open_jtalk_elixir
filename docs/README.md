# Documentation

This directory contains focused user guides and long-lived design decisions.
The top-level README remains the front door, and module documentation remains
the public API reference.

## Where to start

- [Project README](../README.md): introduction, installation, quick start, and
  main API
- [`OpenJTalk` module documentation](https://hexdocs.pm/open_jtalk_elixir/OpenJTalk.html):
  options, asset resolution, errors, and diagnostics
- [Building](building.md): native requirements, build flow, and development
  checks
- [Using with Nerves](nerves.md): target builds, audio, and firmware size
- [Architecture Decision Records](adr/README.md): durable design decisions and
  their tradeoffs
- [Release checklist](../RELEASE.md): maintainer-only package verification and
  publishing steps

## Precedence

When documents disagree, use this order:

1. current implementation;
2. module documentation and the top-level `README.md`;
3. accepted ADRs; and
4. historical discussion in issues and pull requests.

The release checklist describes a workflow, not architecture or public API
behavior.

## Layout

```text
docs/
|-- README.md
|-- building.md
|-- nerves.md
`-- adr/
    |-- README.md
    `-- NNNN-decision-title.md
```
