# ADR 0003: Resolve runtime assets by priority

## Status

Accepted and implemented. Retrospectively recorded on 2026-10-04.

## Context

Open JTalk synthesis requires an executable, a dictionary, and an HTS voice.
Bundling these assets under `priv/` gives desktop users a convenient default.

Nerves systems may instead keep large assets under `/data` or provision them
separately to reduce firmware size. Desktop and server systems may already
have suitable assets installed by the operating system. One fixed location
cannot serve all of these cases.

## Decision

For automatic resolution, locate the Open JTalk executable, dictionary, and
voice in this order:

1. a path supplied through an environment variable;
2. an asset bundled under the Elixir application's `priv/` directory; and
3. a supported system installation.

The environment variables are:

- `OPENJTALK_CLI`;
- `OPENJTALK_DICTIONARY_DIR`; and
- `OPENJTALK_VOICE`.

An explicit per-call `:dictionary` or `:voice` option takes precedence over
automatic resolution for that synthesis request.

Resolve `priv/` paths at runtime with `Application.app_dir/2`; do not embed
absolute build-host paths in BEAM files. Cache successful automatic
resolutions in `:persistent_term`. Provide `OpenJTalk.Assets.reset_cache/0` so
an application can re-resolve assets after its environment or filesystem
changes.

## Consequences

### Benefits

- Bundled assets provide a convenient default.
- Nerves applications can place large assets outside the firmware image.
- Existing system installations can be reused.
- Explicit application configuration always wins.
- Build-host paths do not leak into the runtime environment.
- Repeated synthesis avoids repeated filesystem searches.

### Costs

- Two deployments can resolve different assets from the same application
  code.
- Runtime environment changes require an explicit cache reset.
- System discovery requires maintenance of known locations for each OS and
  architecture.

## Constraints

- Preserve the resolution order unless compatibility impact has been assessed.
- Require an explicitly selected dictionary directory to contain `sys.dic`.
- Require an explicitly selected voice path to exist; bundled and system
  discovery continue to search for `.htsvoice` files.
- Do not let new OS-specific searches outrank explicit or bundled assets.
- Keep `OpenJTalk.info/0` available for diagnosing the selected sources.

## References

- `lib/open_jtalk/assets.ex`
- `lib/open_jtalk/info.ex`
- `README.md`
