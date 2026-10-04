# Troubleshooting

Start with runtime diagnostics:

```elixir
{:ok, info} = OpenJTalk.info()
```

The result reports the selected executable, dictionary, voice, and audio
player paths, together with where each was found.

## Error model

Invalid public options raise `ArgumentError`. Filesystem, command, WAV, and
audio-player failures return `{:error, reason}`. This separates programming
mistakes from expected runtime failures.

```elixir
OpenJTalk.play_wav_binary(wav, playback_mode: :stream)
# ** (ArgumentError) ...

{:error, {:dictionary_missing, path}} =
  OpenJTalk.to_wav_binary("こんにちは", dictionary: "/missing/dictionary")
```

## Common errors

| Error | Meaning | What to check |
| --- | --- | --- |
| `{:binary_missing, paths}` | No Open JTalk executable was found | `OPENJTALK_CLI`, bundled build output, and `PATH` |
| `{:dictionary_missing, path}` | No valid dictionary was found | Directory exists and contains `sys.dic` |
| `{:voice_missing, path}` | No voice was found | `OPENJTALK_VOICE` or bundled voice files |
| `{:open_jtalk_exit, status, output}` | Synthesis command failed | Command output; `status` may be `:timeout` |
| `:no_player_found` | No supported audio player was found | Install or include `aplay`, `paplay`, `afplay`, or SoX `play` |
| `{:player_failed, status, output}` | The selected player failed | Audio device, permissions, command output, and timeout |
| `{:parse_failed, index, reason}` | WAV concatenation rejected an input | The indexed input is a complete, supported RIFF/WAV file |

## Asset changes are not taking effect

Successful automatic asset resolutions are cached. Reset them after changing
the environment or filesystem:

```elixir
OpenJTalk.Assets.reset_cache()
```

Then call `OpenJTalk.info/0` again to confirm the new paths.

## Initial download or extraction failed

Confirm that the build host has outbound HTTPS access and the tools listed in
[Building](building.md). To replace incomplete or invalid vendor downloads in a
source checkout, run:

```bash
scripts/prepare_vendor.sh --force
mix compile
```

Downloads that do not match their pinned SHA-256 digest are rejected.

## Synthesis works but playback fails

Generate a WAV without using the system player:

```elixir
{:ok, wav} = OpenJTalk.to_wav_binary("動作確認")
```

If this succeeds, verify the available player, audio device, and application
permissions. On Nerves, confirm that the system image contains the intended
audio stack and player.

Use `playback_mode: :file` to rule out stdin support problems:

```elixir
OpenJTalk.play_wav_binary(wav, playback_mode: :file)
```
