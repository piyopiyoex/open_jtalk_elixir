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
2. Merge the release commit into `main` and update the local `main` branch.
3. Run `mix hex.user whoami` to confirm Hex authentication. Publishing prompts
   for a two-factor authentication code, so run it from an interactive shell.
4. Create the matching annotated Git tag on the merged release commit.
5. Run `MIX_ENV=docs mix hex.publish` and review the package contents before
   confirming. Keep the explicit environment so ExDoc is available.
6. Verify the package and versioned HexDocs page, then push the tag.
7. Create a GitHub Release from the tag, use the matching `CHANGELOG.md` entry
   as its notes, and mark it as the latest release.
8. Verify that Hex lists the new version as latest, the versioned HexDocs page
   loads, the GitHub Release is published, and CI passes for the release commit.
