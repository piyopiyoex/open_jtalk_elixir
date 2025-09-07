defmodule OpenJTalk do
  @moduledoc File.read!("README.md")
             |> String.split("<!-- MODULEDOC -->")
             |> Enum.fetch!(1)

  alias OpenJTalk.{Assets, Runner}

  @typedoc "Voice color adjustment. Range: -0.8..0.8 (values are clamped)."
  @type timbre :: float()

  @typedoc "Pitch shift in semitones. Range: -24..24 (values are clamped)."
  @type pitch_shift :: -24..24

  @typedoc "Speaking rate multiplier. Range: 0.5..2.0 (values are clamped)."
  @type rate :: float()

  @typedoc "Output gain in dB. Typical useful range is about -20..20 (values are clamped)."
  @type gain :: number()

  @type opt ::
          {:timbre, timbre}
          | {:pitch_shift, pitch_shift}
          | {:rate, rate}
          | {:gain, gain}
          | {:voice, Path.t()}
          | {:dictionary, Path.t()}
          | {:timeout, non_neg_integer()}
          | {:out, Path.t()}

  @type opts :: [opt]

  @base_alpha 0.55

  @default_opts [
    timbre: 0.0,
    pitch_shift: 0,
    rate: 1.0,
    gain: 0
  ]

  @doc """
  Synthesize `text` to a WAV file.

  """
  @spec to_wav(binary, opts) :: {:ok, Path.t()} | {:error, term}
  def to_wav(text, opts \\ []) when is_binary(text) do
    out =
      opts[:out] || Path.join(System.tmp_dir!(), "ojt-#{System.unique_integer([:positive])}.wav")

    with {:ok, args} <- args_for(out, opts),
         {:ok, txt, cleanup} <- Runner.write_tmp_text(text) do
      try do
        case Runner.run(args ++ [txt], opts[:timeout]) do
          {:ok, _out} -> {:ok, out}
          {:error, _} = e -> e
        end
      after
        cleanup.()
      end
    end
  end

  @doc """
  Synthesize `text` and return a WAV as a binary.
  """
  @spec to_binary(binary, opts) :: {:ok, binary} | {:error, term}
  def to_binary(text, opts \\ []) when is_binary(text) do
    tmp = Path.join(System.tmp_dir!(), "ojt-#{System.unique_integer([:positive])}.wav")

    try do
      with {:ok, _path} <- to_wav(text, Keyword.put(opts, :out, tmp)),
           {:ok, bin} <- File.read(tmp) do
        {:ok, bin}
      else
        {:error, _} = e -> e
      end
    after
      # Best-effort cleanup; ignore errors
      File.rm(tmp)
    end
  end

  @doc """
  Synthesize `text` and play it via a system audio player.
  """
  @spec say(binary, opts) :: :ok | {:error, term}
  def say(text, opts \\ []) do
    out = Path.join(System.tmp_dir!(), "ojt-#{System.unique_integer([:positive])}.wav")

    try do
      case to_wav(text, Keyword.put_new(opts, :out, out)) do
        {:ok, path} -> OpenJTalk.Player.play_file(path)
        {:error, _} = e -> e
      end
    after
      File.rm(out)
    end
  end

  @doc """
  Return useful information about the local Open JTalk setup.
  """
  @spec info() :: {:ok, map()} | {:error, term()}
  defdelegate info(), to: OpenJTalk.Info

  # ---- internals ---------------------------------------------------------------

  defp args_for(wav_out, user_opts) do
    opts = Keyword.merge(@default_opts, user_opts)

    with {:ok, bin} <- Assets.resolve_bin(),
         {:ok, dic} <- Assets.resolve_dictionary(opts[:dictionary]),
         {:ok, voice} <- Assets.resolve_voice(opts[:voice]) do
      alpha = clamp(@base_alpha + (opts[:timbre] || 0.0), 0.0, 1.0)
      rate = clamp(opts[:rate] || 1.0, 0.5, 2.0)
      fm = clamp(opts[:pitch_shift] || 0, -24, 24)
      gain = clamp(opts[:gain] || 0, -20, 20)

      args =
        [
          "-x",
          dic,
          "-m",
          voice,
          "-ow",
          wav_out,
          "-a",
          to_string(alpha),
          "-r",
          to_string(rate),
          "-g",
          to_string(gain)
        ]
        |> maybe_add_fm(fm)

      {:ok, [bin | args]}
    end
  end

  defp maybe_add_fm(args, 0), do: args
  defp maybe_add_fm(args, fm), do: args ++ ["-fm", to_string(fm)]

  defp clamp(x, lo, hi) when is_number(x) and is_number(lo) and is_number(hi) do
    x |> min(hi) |> max(lo)
  end
end
