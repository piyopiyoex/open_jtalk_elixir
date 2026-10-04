defmodule OpenJTalk.Options do
  @moduledoc false
  # Shared option validation and normalization for synthesis and playback.

  @allowed_keys [
    :timbre,
    :pitch_shift,
    :rate,
    :gain,
    :voice,
    :dictionary,
    :timeout,
    :playback_mode,
    :out
  ]

  @playback_modes [:auto, :file, :stdin]
  @default_timeout 20_000

  @synth_keys [:timbre, :pitch_shift, :rate, :gain, :voice, :dictionary, :timeout]
  @player_keys [:timeout, :playback_mode]
  @context_keys %{
    synth: @synth_keys,
    wav_file: [:out | @synth_keys],
    player: @player_keys,
    say: Enum.uniq(@synth_keys ++ @player_keys)
  }

  @doc "Validate options for synthesis and playback. Returns the original options."
  @spec validate!(keyword()) :: keyword()
  def validate!(opts) when is_list(opts) do
    if Keyword.keyword?(opts) do
      check_known_keys!(opts)
      validate_values!(opts)
      opts
    else
      raise ArgumentError, "OpenJTalk options must be a keyword list"
    end
  end

  def validate!(_opts) do
    raise ArgumentError, "OpenJTalk options must be a keyword list"
  end

  @doc false
  @spec validate_for!(keyword(), :synth | :wav_file | :player | :say) :: keyword()
  def validate_for!(opts, context) when is_map_key(@context_keys, context) do
    opts = validate!(opts)
    check_allowed_keys!(opts, Map.fetch!(@context_keys, context), context)
    opts
  end

  @doc "Return the requested playback mode, defaulting to `:auto`."
  @spec playback_mode(keyword()) :: OpenJTalk.playback_mode()
  def playback_mode(opts), do: Keyword.get(opts, :playback_mode, :auto)

  @doc "Normalize a timeout value to the default when it is absent or invalid."
  @spec normalize_timeout(term()) :: pos_integer()
  def normalize_timeout(nil), do: @default_timeout
  def normalize_timeout(value) when is_integer(value) and value > 0, do: value
  def normalize_timeout(_value), do: @default_timeout

  @doc "Clamp a numeric value between lower and upper bounds."
  @spec clamp(number(), number(), number()) :: number()
  def clamp(value, lower, upper)
      when is_number(value) and is_number(lower) and is_number(upper) do
    value |> min(upper) |> max(lower)
  end

  defp check_known_keys!(opts) do
    unknown =
      opts
      |> Keyword.keys()
      |> Enum.uniq()
      |> Enum.reject(&(&1 in @allowed_keys))

    if unknown != [] do
      raise ArgumentError, "unknown option(s) for OpenJTalk: #{inspect(unknown)}"
    end

    :ok
  end

  defp check_allowed_keys!(opts, allowed, context) do
    invalid = opts |> Keyword.keys() |> Enum.uniq() |> Enum.reject(&(&1 in allowed))

    if invalid != [] do
      raise ArgumentError, "invalid option(s) for #{context}: #{inspect(invalid)}"
    end

    :ok
  end

  defp validate_values!(opts) do
    Enum.each(opts, fn
      {key, value} when key in [:timbre, :rate, :gain] and is_number(value) -> :ok
      {:pitch_shift, value} when is_integer(value) -> :ok
      {key, value} when key in [:voice, :dictionary, :out] and is_binary(value) -> :ok
      {:playback_mode, value} when value in @playback_modes -> :ok
      {:timeout, value} when is_integer(value) and value > 0 -> :ok
      {key, value} -> raise ArgumentError, "invalid value for #{inspect(key)}: #{inspect(value)}"
    end)
  end
end
