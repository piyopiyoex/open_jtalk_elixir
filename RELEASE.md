# Release checklist

Use this checklist from a clean branch based on `main`.

## Prepare

1. Update `@version` in `mix.exs`.
2. Add the release notes to `CHANGELOG.md`.
3. Confirm that dependency and upstream archive changes are intentional.
4. Run the same checks as CI:

   ```bash
   mix format --check-formatted
   shellcheck -x scripts/*.sh
   MIX_ENV=lint mix compile --warnings-as-errors
   MIX_ENV=lint mix dialyzer --format short
   MIX_ENV=lint mix credo --all --strict --format=oneline
   mix test
   ```

5. Generate the documentation and treat warnings as failures:

   ```bash
   MIX_ENV=docs mix docs --warnings-as-errors
   ```

## Verify the package

Build and inspect the exact payload that Hex will receive:

```bash
MIX_ENV=docs mix hex.build
MIX_ENV=docs mix hex.build --unpack --output tmp/hex-package
```

Confirm that the unpacked package contains `lib/`, `scripts/`, `Makefile`, and
`vendor/config/`. The large upstream archives should not be present. Compile
the unpacked package in a clean environment to exercise archive downloading,
the native build, and asset installation.

## Publish

1. Commit the version and changelog changes using the existing release commit
   style, for example `v0.4.0 release`.
2. Create the matching annotated Git tag.
3. Run `MIX_ENV=docs mix hex.publish` and review the package contents before
   confirming.
4. Push the release commit and tag.
5. Verify the HexDocs page and the CI run for the tag/commit.
