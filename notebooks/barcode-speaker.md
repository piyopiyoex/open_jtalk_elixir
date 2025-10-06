# OpenJTalk - Barcode Speaker

```elixir
Mix.install([
  {:open_jtalk_elixir, "~> 0.3.0"}
])
```

## Introduction

This notebook demonstrates a practical Open JTalk technique for reading numeric barcodes by caching digit WAVs (0–9) and then concatenating them for playback.

This approach is far more efficient than synthesizing an entire barcode every time.

## Quick smoke test

Let’s begin with a quick test to see if everything works:

```elixir
OpenJTalk.say("元氣ですか、元氣があればなんでもできる")
```

If you hear a voice, you’re all set!

## Why cache digit WAVs?

Barcodes like `"4901234567890"` are just long strings of digits.
Synthesizing the entire number every time is wasteful — the pronunciation of each digit never changes.

A better way is to synthesize each digit once, store those short WAVs in memory, and concatenate them on demand.
This makes playback instant, consistent, and fully offline.

```elixir
digit_wav_lookup =
  0..9
  |> Enum.map(&Integer.to_string/1)
  |> Map.new(fn digit ->
    {:ok, wav} = OpenJTalk.to_wav_binary(digit)
    {digit, wav}
  end)
```

Now you can easily “speak” any number by concatenating cached clips:

```elixir
barcode = "4901234567890"

{:ok, merged} =
  barcode
  |> String.graphemes()
  |> Enum.map(&Map.fetch!(digit_wav_lookup, &1))
  |> then(&OpenJTalk.Wav.concat_binaries(&1))

OpenJTalk.play_wav_binary(merged)
```

On a typical laptop, the speed gain from caching may seem modest.
But on resource-constrained devices — such as those running Nerves — the improvement is dramatic.
What once took seconds can now be played back almost instantly, simply by skipping repeated synthesis.

## DigitSpeaker: a tiny barcode speaker

Let’s wrap everything into a single module that:

* Synthesizes digits `0–9` in parallel
* Caches their WAVs using `:persistent_term`
* Reads any barcode by joining and playing the cached audio

```elixir
defmodule SampleApp.DigitSpeaker do
  @digits Enum.map(0..9, &Integer.to_string/1)
  @cache_key {__MODULE__, :digit_wav_cache}

  @spec speak_barcode(String.t(), keyword) :: :ok | {:error, term}
  def speak_barcode(barcode, opts \\ []) when is_binary(barcode) do
    cache = get_or_build_cache()

    wavs =
      barcode
      |> String.graphemes()
      |> Enum.filter(&(&1 in @digits))
      |> Enum.map(&Map.fetch!(cache, &1))

    case wavs do
      [] ->
        {:error, :blank}

      _ ->
        with {:ok, merged} <- OpenJTalk.Wav.concat_binaries(wavs) do
          OpenJTalk.play_wav_binary(merged, opts)
        end
    end
  end

  defp get_or_build_cache do
    case :persistent_term.get(@cache_key, :none) do
      :none ->
        cache = build_cache()
        :persistent_term.put(@cache_key, cache)
        cache

      cache ->
        cache
    end
  end

  defp build_cache do
    @digits
    |> Task.async_stream(&synthesize_digit/1, timeout: :infinity, ordered: true)
    |> Enum.map(fn
      {:ok, {:ok, {digit, wav}}} -> {digit, wav}
      {:ok, {:error, {digit, reason}}} -> raise "digit #{digit} synthesis failed: #{inspect(reason)}"
      {:exit, reason} -> raise "task exit during synthesis: #{inspect(reason)}"
      other -> raise "unexpected task result: #{inspect(other)}"
    end)
    |> Map.new()
  end

  defp synthesize_digit(digit) do
    case OpenJTalk.to_wav_binary(digit) do
      {:ok, wav} -> {:ok, {digit, wav}}
      {:error, reason} -> {:error, {digit, reason}}
    end
  end
end
```

Now, give it a try:

```elixir
SampleApp.DigitSpeaker.speak_barcode("4901234567890")
```

This runs entirely offline, plays instantly, and avoids re-synthesizing digits each time.
Once the WAV cache is built, it’s just fast binary concatenation and playback.

## Done!

You now have a fast, reusable barcode speaker with OpenJTalk 🎉 
