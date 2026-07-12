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

  @doc "Validate options for synthesis and playback. Returns the original options."
  @spec validate!(keyword()) :: keyword()
  def validate!(opts) when is_list(opts) do
    if Keyword.keyword?(opts) do
      check_known_keys!(opts)
      validate_playback_mode!(opts)
      validate_timeout!(opts)
      opts
    else
      raise ArgumentError, "OpenJTalk options must be a keyword list"
    end
  end

  def validate!(_opts) do
    raise ArgumentError, "OpenJTalk options must be a keyword list"
  end

  @doc "Return the requested playback mode, defaulting to `:auto`."
  @spec playback_mode(keyword()) :: OpenJTalk.playback_mode()
  def playback_mode(opts), do: Keyword.get(opts, :playback_mode, :auto)

  @doc "Normalize a timeout value to the default when it is absent or invalid."
  @spec normalize_timeout(term()) :: non_neg_integer()
  def normalize_timeout(nil), do: @default_timeout
  def normalize_timeout(value) when is_integer(value) and value >= 0, do: value
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

  defp validate_playback_mode!(opts) do
    case Keyword.fetch(opts, :playback_mode) do
      :error -> :ok
      {:ok, mode} when mode in @playback_modes -> :ok
      {:ok, bad} -> raise ArgumentError, "invalid value for :playback_mode: #{inspect(bad)}"
    end
  end

  defp validate_timeout!(opts) do
    case Keyword.fetch(opts, :timeout) do
      :error -> :ok
      {:ok, timeout} when is_integer(timeout) and timeout >= 0 -> :ok
      {:ok, bad} -> raise ArgumentError, "invalid value for :timeout: #{inspect(bad)}"
    end
  end
end
