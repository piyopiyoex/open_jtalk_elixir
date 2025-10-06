# OpenJTalk - Getting Started

```elixir
Mix.install([
  {:open_jtalk_elixir, "~> 0.3.0"},
  {:kino, "~> 0.17.0"}
])
```

## Introduction

`open_jtalk_elixir` is a wrapper around [Open JTalk](https://open-jtalk.sp.nitech.ac.jp/), a Japanese text-to-speech engine.
It lets you synthesize Japanese speech from Elixir, save it as a WAV file, or play it directly on your system.

This notebook walks you through the basics — from generating simple phrases to customizing speech and combining WAVs for personalized messages.

You need a system audio player: `afplay` (macOS), `aplay` or `paplay` (Linux), or SoX's `play`.

## Quick smoke test

Let’s begin with a quick test to see if everything works:

```elixir
OpenJTalk.say("元氣ですか、元氣があればなんでもできる")
```

If you hear a voice, you’re all set!

This uses your system’s audio player to speak directly, without writing to a file.

## Save speech to a WAV file

Sometimes, you’ll want to save speech output as a file — for reuse, sharing, or offline playback.

```elixir
{:ok, path} = OpenJTalk.to_wav_file("ファイルに保存します。", out: "/tmp/hello.wav")
:ok = OpenJTalk.play_wav_file(path)
path
```

This creates a standard WAV file on disk.
You can inspect it, open it in an editor, or play it using any audio tool.

## In-memory WAV bytes & playback

If you don’t need to persist audio to disk, you can keep everything in memory:

```elixir
{:ok, wav} = OpenJTalk.to_wav_binary("メモリー上のWAVを再生します。")
:ok = OpenJTalk.play_wav_binary(wav)
byte_size(wav)
```

This gives you raw binary WAV data, which is ideal for piping into another process or storing temporarily.

## Tweak the voice

You can customize speech output using synthesis options like speed, pitch, timbre, and volume.

```elixir
{:ok, wav} = OpenJTalk.to_wav_binary("少しゆっくり、低めの声で。", rate: 0.8, pitch_shift: -5)
OpenJTalk.play_wav_binary(wav)
```

A few useful parameters:

* `:rate` – Speech speed (0.5–2.0)
* `:pitch_shift` – Pitch shift in semitones (-24 to 24)
* `:timbre` – Voice color (-0.8 to 0.8)
* `:gain` – Volume adjustment in dB (-20 to 20)

These let you fine-tune how expressive or robotic the voice sounds.

## Concatenate WAVs

For dynamic scenarios like notifications or barcode reading, it’s helpful to join multiple WAVs together.

We’ll create a personalized greeting by asking for a name and combining speech clips.

```elixir
OpenJTalk.say("お名前を入力してください")
name_input = Kino.Input.text("Name")
```

Once we have the name, we can synthesize two parts and merge them:

```elixir
name =
  case Kino.Input.read(name_input) do
    "" -> "ぴよぴよ"
    n -> n
  end

{:ok, wav1} = OpenJTalk.to_wav_binary("#{name}さん")
{:ok, wav2} = OpenJTalk.to_wav_binary("元氣ですか？")

{:ok, merged_wav} = OpenJTalk.Wav.concat_binaries([wav1, wav2])
OpenJTalk.play_wav_binary(merged_wav)
```

This lets you build custom speech without re-generating entire phrases every time — just reuse building blocks.

## You’re ready to explore more!

That’s it for the basics — you’ve now spoken Japanese text from Elixir, customized the voice, and even built a dynamic greeting using concatenated WAVs.

To dive deeper, checkout the [offcial documentation](https://hexdocs.pm/open_jtalk_elixir).

You now have everything you need to make your Elixir app talk — in fluent, expressive Japanese 🎉
