# Using with Nerves

Nerves cross-compilation is a standard build path for `open_jtalk_elixir`.
The package uses the selected target toolchain and installs runtime files under
the dependency's `priv/` directory.

## Quick start

```bash
export MIX_TARGET=rpi4
mix deps.get
mix compile
mix firmware
```

On the device:

```elixir
{:ok, info} = OpenJTalk.info()
:ok = OpenJTalk.say("こんにちは")
```

## Target build behavior

When `MIX_TARGET` is set:

- the native build honors `CC`, `CXX`, `AR`, `RANLIB`, and `STRIP` from the
  target toolchain;
- native outputs are separated by target triplet;
- full static linking is requested by default; and
- the dictionary and voice are bundled by default.

Full static linking depends on libraries supplied by the target toolchain. Set
`OPENJTALK_FULL_STATIC=0` when dynamic linking is required and the necessary
runtime libraries are available in the system.

## Audio playback

`OpenJTalk.say/2` needs a supported system audio player. Most Nerves images
that provide ALSA playback use `aplay`.

If the system does not include a supported player, generate WAV data with
`OpenJTalk.to_wav_binary/2` or `OpenJTalk.to_wav_file/2` and pass it to the
application's audio path.

## Firmware size

Approximate uncompressed sizes are:

| Component | Size |
| --- | ---: |
| Open JTalk dictionary | 103 MB |
| Mei voice | 2.2 MB |
| Open JTalk CLI | 2.4 MB |

For size-constrained firmware, disable bundled assets:

```bash
MIX_TARGET=rpi4 OPENJTALK_BUNDLE_ASSETS=0 mix deps.compile open_jtalk_elixir
```

This also keeps the dictionary and MMDAgent example archive out of vendor
preparation, so the build downloads only the three native source archives.
For restricted-network or offline builds, pre-populate the verified cache
described in [Building](building.md#local-cache-and-offline-builds).

Provision the dictionary and voice separately, for example under `/data`, then
configure their runtime paths:

```elixir
System.put_env("OPENJTALK_CLI", "/data/open_jtalk/bin/open_jtalk")
System.put_env("OPENJTALK_DICTIONARY_DIR", "/data/open_jtalk/dic")
System.put_env("OPENJTALK_VOICE", "/data/open_jtalk/voices/mei_normal.htsvoice")

OpenJTalk.Assets.reset_cache()
```

Omit `OPENJTALK_CLI` when the executable remains bundled with the application.

How assets reach persistent storage is application-specific and outside this
library's scope.

## Support boundary

CI cross-compiles and inspects an aarch64 RPi 4 executable. New Nerves targets
should also be tested on hardware through actual synthesis and playback; a
successful cross-build alone does not validate the audio path.

See [Building](building.md) for native build details and the
[`OpenJTalk` module documentation](https://hexdocs.pm/open_jtalk_elixir/OpenJTalk.html#module-runtime-assets)
for the complete asset-resolution rules.
