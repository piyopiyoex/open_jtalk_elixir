# Configuration

The default configuration is intended to work without application settings.
Options are passed as keyword lists to the public API when customization is
needed.

## Synthesis options

| Option | Accepted value | Behavior |
| --- | --- | --- |
| `:timbre` | number | Voice-color offset, clamped to `-0.8..0.8` |
| `:pitch_shift` | integer | Semitone shift, clamped to `-24..24` |
| `:rate` | number | Speaking speed, clamped to `0.5..2.0` |
| `:gain` | number | Output gain in dB, clamped to `-20..20` |
| `:voice` | path | Use a specific voice file for this request |
| `:dictionary` | path | Use a directory containing `sys.dic` for this request |
| `:timeout` | positive integer | Command timeout in milliseconds; default `20_000` |

`OpenJTalk.to_wav_file/2` also accepts `:out` for the destination path.
`OpenJTalk.say/2` intentionally does not accept `:out`; call
`to_wav_file/2` followed by `play_wav_file/2` when the generated file must be
retained.

## Playback options

| Option | Accepted value | Behavior |
| --- | --- | --- |
| `:playback_mode` | `:auto`, `:stdin`, or `:file` | Select how WAV data reaches the player |
| `:timeout` | positive integer | Player timeout in milliseconds; default `20_000` |

`:auto` prefers stdin playback and falls back to a temporary file when stdin
is unavailable. `:stdin` also falls back when the selected player cannot
accept stdin. `:file` always uses a temporary file for in-memory WAV data.

## Runtime asset resolution

Synthesis needs three assets:

- the `open_jtalk` executable;
- a dictionary containing `sys.dic`; and
- an HTS voice.

An explicit per-call `:dictionary` or `:voice` option has the highest priority
for that request. Otherwise, assets are resolved in this order:

1. environment variable;
2. bundled file under the application's `priv/` directory; and
3. supported system installation.

### Executable

| Source | Location |
| --- | --- |
| Environment | `OPENJTALK_CLI` |
| Bundled | `priv/bin/open_jtalk` |
| System | `open_jtalk` on `PATH` |

### Dictionary

| Source | Location |
| --- | --- |
| Environment | `OPENJTALK_DICTIONARY_DIR`, containing `sys.dic` |
| Bundled | `priv/dictionary/` |
| System | Known Open JTalk dictionary locations |

System discovery includes common Debian, Ubuntu, and Homebrew locations such
as `/var/lib/mecab/dic/open-jtalk/naist-jdic` and
`/usr/lib/*/mecab/dic/open-jtalk/naist-jdic`.

### Voice

| Source | Location |
| --- | --- |
| Environment | `OPENJTALK_VOICE` |
| Bundled | First `priv/voices/**/*.htsvoice` match |
| System | Known HTS voice locations |

System discovery searches `/usr/share/hts-voice/**`,
`/usr/local/share/hts-voice/**`, and the corresponding Homebrew prefix.

## Refreshing cached assets

Successful automatic resolutions are cached. Reset the cache after changing
environment variables or moving files at runtime:

```elixir
OpenJTalk.Assets.reset_cache()
```

Use `OpenJTalk.info/0` to inspect the resolved path and source for each runtime
component.
