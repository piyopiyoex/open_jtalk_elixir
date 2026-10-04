# Documentation

This directory contains focused user guides and long-lived design decisions.
The top-level README remains the front door, and module documentation remains
the public API reference.

## Where to start

- [Project README](../README.md): introduction, installation, quick start, and
  main API
- [Building](building.md): native requirements, build flow, and development
  checks
- [Configuration](configuration.md): API options and runtime asset resolution
- [Using with Nerves](nerves.md): target builds, audio, and firmware size
- [Troubleshooting](troubleshooting.md): runtime errors and diagnostic steps
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
|-- configuration.md
|-- nerves.md
|-- troubleshooting.md
`-- adr/
    |-- README.md
    `-- NNNN-decision-title.md
```
