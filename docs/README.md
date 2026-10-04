# Documentation

This directory contains project documentation that explains long-lived design
decisions. Usage instructions and the current public API remain in the
top-level README and module documentation.

## Where to start

- [Project README](../README.md): installation, public API, configuration, and
  troubleshooting
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
`-- adr/
    |-- README.md
    `-- NNNN-decision-title.md
```
