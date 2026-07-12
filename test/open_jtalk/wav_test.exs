defmodule OpenJTalk.WavTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  test "parse/1 skips padding after an odd-sized ignored chunk" do
    wav = pcm_wav(<<1, 2>>, chunks_before_fmt: [chunk("JUNK", <<255>>)])

    assert {:ok, parsed} = OpenJTalk.Wav.parse(wav)
    assert parsed.data == <<1, 2>>
  end

  test "concat_binaries/1 pads odd-sized output so it parses cleanly" do
    first = pcm_wav(<<1>>)
    second = pcm_wav(<<2, 3>>)

    assert {:ok, merged} = OpenJTalk.Wav.concat_binaries([first, second])
    assert {:ok, parsed} = OpenJTalk.Wav.parse(merged)
    assert parsed.data == <<1, 2, 3>>
    assert riff_size(merged) + 8 == byte_size(merged)
    assert :binary.last(merged) == 0
  end

  defp mk_wav!(text) do
    {:ok, wav} = OpenJTalk.to_wav_binary(text)
    wav
  end

  test "concat_binaries/1 merges multiple OpenJTalk outputs into one WAV", %{tmp_dir: tmp} do
    a = mk_wav!("これは一つ目。")
    b = mk_wav!("これは二つ目。")
    c = mk_wav!("これは三つ目。")

    assert {:ok, merged} = OpenJTalk.Wav.concat_binaries([a, b, c])
    assert <<"RIFF", _::binary>> = merged

    out = Path.join(tmp, "merged.wav")
    :ok = File.write(out, merged)
    assert File.exists?(out)

    assert byte_size(merged) > byte_size(a)
    assert byte_size(merged) > byte_size(b)
    assert byte_size(merged) > byte_size(c)
  end

  test "concat_files/1 reads paths and merges", %{tmp_dir: tmp} do
    a = mk_wav!("ファイルその1")
    b = mk_wav!("ファイルその2")

    p1 = Path.join(tmp, "a.wav")
    p2 = Path.join(tmp, "b.wav")
    :ok = File.write(p1, a)
    :ok = File.write(p2, b)

    assert {:ok, merged} = OpenJTalk.Wav.concat_files([p1, p2])
    assert <<"RIFF", _::binary>> = merged
    assert byte_size(merged) > max(byte_size(a), byte_size(b))
  end

  test "concat_binaries/1 errors on empty input" do
    assert {:error, :empty_input} = OpenJTalk.Wav.concat_binaries([])
  end

  test "concat_binaries/1 errors when formats differ (byte_rate tweak)" do
    a = mk_wav!("同一フォーマットA")
    b = tweak_byte_rate(a, +1)

    # Tinkering byte_rate breaks internal consistency -> :inconsistent_format
    assert {:error, :inconsistent_format} = OpenJTalk.Wav.concat_binaries([a, b])
  end

  @tag :audio
  test "concatenated WAV can be played (stdin preferred, file fallback)", %{tmp_dir: tmp} do
    a = mk_wav!("これは一つ目。")
    b = mk_wav!("これは二つ目。")
    c = mk_wav!("これは三つ目。")
    assert {:ok, merged} = OpenJTalk.Wav.concat_binaries([a, b, c])
    assert <<"RIFF", _::binary>> = merged

    cond do
      OpenJTalk.Player.stdin_available?() ->
        assert :ok = OpenJTalk.play_wav_binary(merged, playback_mode: :stdin)

      OpenJTalk.Player.available?() ->
        path = Path.join(tmp, "merged_play.wav")
        :ok = File.write(path, merged)
        assert :ok = OpenJTalk.play_wav_file(path)

      true ->
        IO.puts("⚠️  No audio player available; skipping concatenated playback test.")
        assert true
    end
  end

  defp tweak_byte_rate(
         <<"RIFF", riff_size::little-32, "WAVE", "fmt ", fsize::little-32,
           fmt::binary-size(fsize), rest::binary>>,
         delta
       ) do
    <<
      af::little-16,
      ch::little-16,
      sr::little-32,
      br::little-32,
      ba::little-16,
      bps::little-16,
      tail::binary
    >> = fmt

    new_br = br + delta

    new_fmt =
      <<
        af::little-16,
        ch::little-16,
        sr::little-32,
        new_br::little-32,
        ba::little-16,
        bps::little-16,
        tail::binary
      >>

    <<"RIFF", riff_size::little-32, "WAVE", "fmt ", fsize::little-32, new_fmt::binary,
      rest::binary>>
  end

  defp pcm_wav(data, opts \\ []) do
    sample_rate = Keyword.get(opts, :sample_rate, 16_000)
    bits_per_sample = Keyword.get(opts, :bits_per_sample, 8)
    channels = Keyword.get(opts, :channels, 1)
    block_align = div(channels * bits_per_sample, 8)
    byte_rate = sample_rate * block_align

    fmt_body =
      <<1::little-16, channels::little-16, sample_rate::little-32, byte_rate::little-32,
        block_align::little-16, bits_per_sample::little-16>>

    body = [
      "WAVE",
      Keyword.get(opts, :chunks_before_fmt, []),
      chunk("fmt ", fmt_body),
      chunk("data", data)
    ]

    ["RIFF", <<IO.iodata_length(body)::little-32>>, body]
    |> IO.iodata_to_binary()
  end

  defp chunk(id, body) when byte_size(id) == 4 and is_binary(body) do
    [id, <<byte_size(body)::little-32>>, body, padding(body)]
  end

  defp padding(body) when rem(byte_size(body), 2) == 1, do: <<0>>
  defp padding(_body), do: <<>>

  defp riff_size(<<"RIFF", size::little-32, _rest::binary>>), do: size
end
