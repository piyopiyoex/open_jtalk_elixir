# ADR 0001: Run Open JTalk as an external CLI

## Status

Accepted and implemented. Retrospectively recorded on 2026-10-04.

## Context

`open_jtalk_elixir` is a thin Elixir wrapper around Open JTalk. Open JTalk is
implemented primarily in native C and C++ code. Elixir could integrate with it
through a NIF or custom native binding, or it could invoke the existing
`open_jtalk` command as an external process.

The library prioritizes:

- preserving the behavior of the upstream Open JTalk implementation;
- keeping the boundary between BEAM and native code small;
- using the same basic architecture on Linux, macOS, and Nerves;
- avoiding maintenance of a separate binding to Open JTalk internals;
- isolating native failures from BEAM memory; and
- favoring a simple design that remains stable over time.

## Decision

Run the `open_jtalk` CLI as an external process instead of linking Open JTalk
directly into BEAM.

The Elixir layer is responsible for:

- resolving the executable, dictionary, and voice;
- translating Elixir options into command-line arguments;
- managing temporary text and WAV files;
- converting command exits and timeouts into Elixir return values; and
- providing Elixir-oriented helpers for WAV handling and playback.

Use `MuonTrap` to execute external commands. Keep `OpenJTalk.Command` as the
small, replaceable boundary around command execution. A NIF is not part of the
standard execution path.

## Consequences

### Benefits

- The wrapper reuses the established Open JTalk CLI behavior.
- It does not depend strongly on Open JTalk's internal C APIs.
- Native faults are less likely to affect BEAM memory directly.
- Linux, macOS, and Nerves can share one Elixir API and execution model.
- Tests can replace the command runner at a narrow boundary.
- The wrapper remains small.

### Costs

- Each synthesis starts an external process.
- Open JTalk's file-oriented CLI requires temporary files for text input and
  WAV output.
- Internal Open JTalk APIs are unavailable through this interface.
- The CLI argument contract becomes a compatibility boundary.

## Constraints

- Reconsider this decision before adding a direct binding to Open JTalk's C
  API.
- Keep `OpenJTalk.Command` narrow.
- Handle exit status, output, and timeout results explicitly.
- Do not move native synthesis into BEAM without a measured need.

## References

- `lib/open_jtalk.ex`
- `lib/open_jtalk/command.ex`
- `lib/open_jtalk/synth.ex`
- `README.md`
