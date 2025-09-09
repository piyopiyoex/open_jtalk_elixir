# Changelog

## v0.2.0

### Highlights

- **Simpler build**: consolidated native build into one script; removed configure “stamp”.
- **Assets bundled by default**: dictionary + Mei voice now bundled into `priv/` unless opted out.
- **Wider platform support**: host builds verified on Linux x86_64, Linux aarch64, and macOS 14 (arm64).
- **Cross-compile**: tested `MIX_TARGET=rpi4` (aarch64/Nerves).
- **Better triplet detection**: inject modern `config.sub/config.guess` to fix errors like
  `arm64-apple-darwin… not recognized`.

### Breaking / Migration

- Env vars renamed:
  - `FULL_STATIC` → `OPENJTALK_FULL_STATIC`
  - `BUNDLE_ASSETS` → `OPENJTALK_BUNDLE_ASSETS`
- If you previously relied on assets **not** being bundled, set `OPENJTALK_BUNDLE_ASSETS=0`.

## v0.1.0

Initial release
