defmodule OpenJTalk.Player do
  @moduledoc """
  Internal audio playback adapter.
  """

  @players [
    {"aplay", ["-q"]},
    {"paplay", []},
    {"afplay", []},
    {"play", ["-q"]}
  ]

  @doc """
  Returns a uniform info map about the system audio player.
  """
  @spec info() :: %{path: String.t() | nil, source: :system | :none}
  def info do
    case resolve() do
      {:ok, {_cmd, _args, path}} -> %{path: path, source: :system}
      {:error, :no_player_found} -> %{path: nil, source: :none}
    end
  end

  @doc """
  Plays a WAV file via the first available system audio player.
  """
  @spec play_file(Path.t()) :: :ok | {:error, term}
  def play_file(path) do
    with {:ok, {cmd, args, _path}} <- resolve(),
         {_out, 0} <- System.cmd(cmd, args ++ [path], stderr_to_stdout: true) do
      :ok
    else
      {:error, _} = e -> e
      {_out, status} -> {:error, {:player_failed, status}}
    end
  end

  @doc """
  Returns `true` if a supported player is available on the host.
  """
  def available?(), do: match?({:ok, _}, resolve())

  # Returns {:ok, {cmd, args, abs_path}} or {:error, :no_player_found}
  defp resolve do
    Enum.find_value(@players, {:error, :no_player_found}, fn {cmd, args} ->
      case System.find_executable(cmd) do
        nil -> false
        path -> {:ok, {cmd, args, path}}
      end
    end)
  end
end
