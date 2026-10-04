# open_jtalk_elixir

[![Hex version](https://img.shields.io/hexpm/v/open_jtalk_elixir.svg "Hex version")](https://hex.pm/packages/open_jtalk_elixir)
[![CI](https://github.com/piyopiyoex/open_jtalk_elixir/actions/workflows/ci.yml/badge.svg)](https://github.com/piyopiyoex/open_jtalk_elixir/actions/workflows/ci.yml)

[![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fpiyopiyoex%2Fopen_jtalk_elixir%2Fblob%2Fmain%2Fnotebooks%2Fgetting-started.md)

<!-- MODULEDOC -->

Japanese text-to-speech for Elixir, powered by [Open JTalk](http://open-jtalk.sourceforge.net/).

```elixir
OpenJTalk.say("こんにちは")
```

## Why this package?

- A small Elixir API for speech playback and WAV generation
- Automatic native builds with pinned, verified Open JTalk dependencies
- Support for Linux, macOS, and Nerves

## Installation

Add `open_jtalk_elixir` to your dependencies:

```elixir
def deps do
  [
    {:open_jtalk_elixir, "~> 0.3"}
  ]
end
```

Then fetch dependencies and compile:

```bash
mix deps.get
mix compile
```

The first compile builds the required native components and may download
verified source and runtime assets. See [Building](docs/building.md) for system
requirements and the complete build flow.

## Quick start

Speak text through an available system audio player:

```elixir
:ok = OpenJTalk.say("こんにちは")
```

Generate WAV data in memory:

```elixir
{:ok, wav} = OpenJTalk.to_wav_binary("こんにちは")
```

Write a WAV file:

```elixir
{:ok, path} = OpenJTalk.to_wav_file("こんにちは", out: "/tmp/greeting.wav")
```

`say/2` uses `aplay`, `paplay`, `afplay`, or SoX `play`, depending on what is
available on the system.

## Main API

| Function | Purpose |
| --- | --- |
| `OpenJTalk.say/2` | Synthesize and play speech |
| `OpenJTalk.to_wav_binary/2` | Return synthesized RIFF/WAV bytes |
| `OpenJTalk.to_wav_file/2` | Write synthesized speech to a WAV file |
| `OpenJTalk.play_wav_binary/2` | Play existing WAV data |
| `OpenJTalk.play_wav_file/2` | Play an existing WAV file |
| `OpenJTalk.Wav.concat_binaries/1` | Concatenate compatible WAV binaries |
| `OpenJTalk.Wav.concat_files/1` | Concatenate compatible WAV files |

Compatible WAV data can be joined without re-encoding:

```elixir
{:ok, a} = OpenJTalk.to_wav_binary("一つ目")
{:ok, b} = OpenJTalk.to_wav_binary("二つ目")
{:ok, merged} = OpenJTalk.Wav.concat_binaries([a, b])
```

## Common options

```elixir
OpenJTalk.say("こんにちは", rate: 1.1, pitch_shift: 2, gain: 1)
```

| Option | Meaning | Default |
| --- | --- | --- |
| `:rate` | Speaking speed, clamped to `0.5..2.0` | `1.0` |
| `:pitch_shift` | Semitone shift, clamped to `-24..24` | `0` |
| `:timbre` | Voice-color offset, clamped to `-0.8..0.8` | `0.0` |
| `:gain` | Output gain in dB, clamped to `-20..20` | `0` |

See [Configuration](docs/configuration.md) and the
[HexDocs API reference](https://hexdocs.pm/open_jtalk_elixir) for all options.

<!-- MODULEDOC -->

## Nerves

Nerves is a supported build path. In common cases, add the dependency and
compile normally for the selected `MIX_TARGET`.

The bundled dictionary is about 103 MB uncompressed, so firmware size deserves
an explicit decision. See [Using with Nerves](docs/nerves.md) for build behavior,
audio requirements, and external asset configuration.

## Supported platforms and requirements

| Build | CI coverage |
| --- | --- |
| Linux x86_64 | Host build and tests |
| Linux aarch64 | Host build and tests |
| macOS 14 arm64 | Host build and tests |
| Nerves RPi 4 aarch64 | Cross-compilation |

The project supports Elixir 1.15 and later. Native compilation requires a C/C++
toolchain, `make`, `curl`, `tar`, and `unzip`. A Hex installation normally
needs outbound HTTPS access during its first build. See
[Building](docs/building.md) for details.

## Documentation

- [HexDocs API reference](https://hexdocs.pm/open_jtalk_elixir)
- [Building and development](docs/building.md)
- [Configuration and asset resolution](docs/configuration.md)
- [Using with Nerves](docs/nerves.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Architecture Decision Records](https://github.com/piyopiyoex/open_jtalk_elixir/tree/main/docs/adr)

## License

`open_jtalk_elixir` is released under the
[Apache License 2.0](https://github.com/piyopiyoex/open_jtalk_elixir/blob/main/LICENSE).

The Hex package does not contain the upstream source or asset archives, but a
build may download these pinned third-party components:

- [Open JTalk 1.11](http://open-jtalk.sourceforge.net/) - Modified BSD
- [HTS Engine API 1.10](http://hts-engine.sourceforge.net/) - Modified BSD
- [MeCab 0.996](https://taku910.github.io/mecab/) - GPL, LGPL, or BSD; used
  under the BSD terms
- [Open JTalk Dictionary 1.11](https://sourceforge.net/projects/open-jtalk/files/Dictionary/)
  - BSD-style license by NAIST
- [HTS Voice "Mei"](https://sourceforge.net/projects/mmdagent/files/MMDAgent_Example/)
  - CC BY 3.0; "HTS Voice 'Mei' © Nagoya Institute of Technology, licensed
    CC BY 3.0."
