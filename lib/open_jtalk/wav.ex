defmodule OpenJTalk.Wav do
  @moduledoc """
  Minimal WAV utilities: parse and concatenate WAVs that share the same format.

  Supported formats:
    * PCM (audio_format = 1)
    * IEEE float (audio_format = 3)

  Notes:
    * All inputs must have identical: `audio_format`, `channels`, `sample_rate`,
      `bits_per_sample`, `block_align`, `byte_rate`, and any format-extra bytes.
    * This module ignores non-essential chunks (e.g., `LIST`, `cue `). The output
      contains a canonical `fmt ` (format) and `data` only, sized correctly for the
      combined audio.
  """

  @typedoc "Parsed `fmt ` (format) information."
  @type format :: %{
          audio_format: 1 | 3,
          channels: pos_integer,
          sample_rate: pos_integer,
          byte_rate: pos_integer,
          block_align: pos_integer,
          bits_per_sample: pos_integer,
          extra: binary
        }

  @doc """
  Concatenate multiple WAV binaries into a single valid WAV.

  All inputs must have the same format parameters (PCM/float, channels, rate, etc.).

  Returns `{:ok, binary}` or `{:error, reason}`.
  """
  @spec concat_binaries([binary]) :: {:ok, binary} | {:error, term}
  def concat_binaries(list) when is_list(list) do
    with {:ok, parsed} <- parse_all(list),
         :ok <- ensure_same_format(parsed),
         {format, iodata} <- stitch(parsed) do
      {:ok, build_wav(format, iodata)}
    end
  end

  @doc """
  Read and concatenate multiple WAV files indicated by paths.

  Returns `{:ok, binary}` or `{:error, {:file_read_failed, path, reason}}`.
  """
  @spec concat_files([Path.t()]) :: {:ok, binary} | {:error, term}
  def concat_files(paths) when is_list(paths) do
    with {:ok, bins} <- read_all(paths) do
      concat_binaries(bins)
    end
  end

  @doc false
  @spec parse(binary) :: {:ok, %{format: format, data: binary}} | {:error, term}
  def parse(<<"RIFF", _riff_size::little-32, "WAVE", rest::binary>>) do
    case scan_chunks(rest, %{}, nil) do
      {:ok, format, data} -> {:ok, %{format: format, data: data}}
      {:error, _} = e -> e
    end
  end

  def parse(_), do: {:error, :not_a_wav}

  defp read_all(paths) do
    paths
    |> Enum.reduce_while({:ok, []}, fn p, {:ok, acc} ->
      case File.read(p) do
        {:ok, bin} -> {:cont, {:ok, [bin | acc]}}
        {:error, reason} -> {:halt, {:error, {:file_read_failed, p, reason}}}
      end
    end)
    |> case do
      {:ok, bins} -> {:ok, Enum.reverse(bins)}
      error -> error
    end
  end

  defp parse_all(bins) do
    bins
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {bin, idx}, {:ok, acc} ->
      case parse(bin) do
        {:ok, parsed} -> {:cont, {:ok, [parsed | acc]}}
        {:error, reason} -> {:halt, {:error, {:parse_failed, idx, reason}}}
      end
    end)
    |> case do
      {:ok, rev} -> {:ok, Enum.reverse(rev)}
      other -> other
    end
  end

  # Chunk scanner: find "fmt " and "data" (ignores others).
  defp scan_chunks(<<"fmt ", size::little-32, body::binary-size(size), rest::binary>>, acc, data) do
    case parse_format(body) do
      {:ok, format} -> scan_chunks(skip_padding(rest, size), Map.put(acc, :format, format), data)
      {:error, _} = e -> e
    end
  end

  defp scan_chunks(<<"data", size::little-32, body::binary-size(size), rest::binary>>, acc, nil) do
    scan_chunks(skip_padding(rest, size), acc, body)
  end

  # skip any other chunk
  defp scan_chunks(
         <<_id::binary-4, size::little-32, _skip::binary-size(size), rest::binary>>,
         acc,
         data
       ),
       do: scan_chunks(skip_padding(rest, size), acc, data)

  defp scan_chunks(<<>>, %{format: format}, data) when is_map(format) and is_binary(data),
    do: {:ok, format, data}

  defp scan_chunks(<<>>, _acc, _data), do: {:error, :missing_format_or_data}

  defp skip_padding(<<_padding, rest::binary>>, size) when rem(size, 2) == 1, do: rest
  defp skip_padding(rest, _size), do: rest

  defp parse_format(<<
         audio_format::little-16,
         channels::little-16,
         sample_rate::little-32,
         byte_rate::little-32,
         block_align::little-16,
         bits_per_sample::little-16,
         rest::binary
       >>)
       when audio_format in [1, 3] do
    extra =
      case rest do
        # cbSize == 0 (or absent)
        <<0::little-16, _::binary>> -> <<>>
        <<cb::little-16, extra::binary-size(cb), _tail::binary>> -> extra
        <<>> -> <<>>
      end

    {:ok,
     %{
       audio_format: audio_format,
       channels: channels,
       sample_rate: sample_rate,
       byte_rate: byte_rate,
       block_align: block_align,
       bits_per_sample: bits_per_sample,
       extra: extra
     }}
  end

  defp parse_format(_), do: {:error, :unsupported_or_malformed_format}

  # Verify each parsed header’s internal consistency & all formats match.
  defp ensure_same_format([]), do: {:error, :empty_input}

  defp ensure_same_format([first | rest]) do
    with :ok <- ensure_consistent_format(first.format),
         :ok <- ensure_all_consistent(rest) do
      ensure_all_match(first.format, rest)
    end
  end

  # byte_rate must equal sample_rate * channels * (bits_per_sample / 8)
  # block_align must equal channels * (bits_per_sample / 8)
  defp ensure_consistent_format(%{
         channels: channels,
         sample_rate: sample_rate,
         byte_rate: byte_rate,
         block_align: block_align,
         bits_per_sample: bits_per_sample
       }) do
    bytes_per_sample = div(bits_per_sample, 8)

    cond do
      bits_per_sample not in [8, 16, 24, 32] -> {:error, :inconsistent_format}
      block_align != channels * bytes_per_sample -> {:error, :inconsistent_format}
      byte_rate != sample_rate * channels * bytes_per_sample -> {:error, :inconsistent_format}
      true -> :ok
    end
  end

  # Check internal consistency on all remaining items; bail fast on error
  defp ensure_all_consistent(list) do
    Enum.reduce_while(list, :ok, fn %{format: f}, :ok ->
      case ensure_consistent_format(f) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  # Check that all formats match the first; bail fast on mismatch
  defp ensure_all_match(first_fmt, list) do
    Enum.reduce_while(list, :ok, fn %{format: f}, :ok ->
      case format_eq?(first_fmt, f) do
        true -> {:cont, :ok}
        false -> {:halt, {:error, :mismatched_formats}}
      end
    end)
  end

  defp format_eq?(a, b) do
    a.audio_format == b.audio_format and
      a.channels == b.channels and
      a.sample_rate == b.sample_rate and
      a.bits_per_sample == b.bits_per_sample and
      a.block_align == b.block_align and
      a.byte_rate == b.byte_rate and
      a.extra == b.extra
  end

  defp stitch(parsed_list) do
    format = hd(parsed_list).format
    data_iodata = Enum.map(parsed_list, & &1.data)
    {format, data_iodata}
  end

  defp build_wav(format, data_iodata) do
    data_size = IO.iodata_length(data_iodata)
    format_chunk = encode_format(format)
    format_size = byte_size(format_chunk)
    riff_size = 4 + padded_chunk_size(format_size) + padded_chunk_size(data_size)

    iodata = [
      "RIFF",
      <<riff_size::little-32>>,
      "WAVE",
      "fmt ",
      <<format_size::little-32>>,
      format_chunk,
      chunk_padding(format_size),
      "data",
      <<data_size::little-32>>,
      data_iodata,
      chunk_padding(data_size)
    ]

    IO.iodata_to_binary(iodata)
  end

  defp padded_chunk_size(size), do: 8 + size + padding_size(size)

  defp encode_format(%{
         audio_format: audio_format,
         channels: channels,
         sample_rate: sample_rate,
         byte_rate: byte_rate,
         block_align: block_align,
         bits_per_sample: bits_per_sample,
         extra: extra
       }) do
    base = <<
      audio_format::little-16,
      channels::little-16,
      sample_rate::little-32,
      byte_rate::little-32,
      block_align::little-16,
      bits_per_sample::little-16
    >>

    case extra do
      <<>> ->
        base

      _ ->
        <<base::binary, byte_size(extra)::little-16, extra::binary>>
    end
  end

  defp chunk_padding(size) when rem(size, 2) == 1, do: <<0>>
  defp chunk_padding(_size), do: <<>>

  defp padding_size(size) when rem(size, 2) == 1, do: 1
  defp padding_size(_size), do: 0
end
