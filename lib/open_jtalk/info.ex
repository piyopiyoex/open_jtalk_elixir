defmodule OpenJTalk.Info do
  @moduledoc """
  Environment diagnostics for the local Open JTalk setup.
  """

  alias OpenJTalk.{Assets, Player}

  @typedoc "Origin tag for a resolved component."
  @type source :: :env | :bundled | :system | :none

  @typedoc "Uniform info entry for a discovered component."
  @type entry :: %{path: String.t() | nil, source: source()}

  @typedoc "Info map returned on success."
  @type info_map :: %{
          bin: entry(),
          dictionary: entry(),
          voice: entry(),
          audio_player: entry()
        }

  @doc """
  Returns a uniform view of the configured Open JTalk environment.
  """
  @spec info() :: {:ok, info_map()} | {:error, term}
  def info() do
    with {:ok, bin} <- Assets.resolve_bin(),
         {:ok, dic} <- Assets.resolve_dictionary(nil),
         {:ok, voice} <- Assets.resolve_voice(nil) do
      {:ok,
       %{
         bin: %{
           path: bin,
           source: classify_source(:bin, bin)
         },
         dictionary: %{
           path: dic,
           source: classify_source(:dic, dic)
         },
         voice: %{
           path: voice,
           source: classify_source(:voice, voice)
         },
         audio_player: Player.info()
       }}
    else
      {:error, _} = e -> e
    end
  end

  defp classify_source(:bin, path) do
    env = System.get_env("OPENJTALK_CLI")
    priv_bin = Application.app_dir(:open_jtalk_elixir, "priv/bin/open_jtalk")

    cond do
      is_binary(env) and Path.expand(env) == Path.expand(path) -> :env
      Path.expand(path) == Path.expand(priv_bin) -> :bundled
      true -> :system
    end
  end

  defp classify_source(:dic, path) do
    env = System.get_env("OPENJTALK_DIC_DIR")
    priv_dic_root = Application.app_dir(:open_jtalk_elixir, "priv/dic")
    path_expanded = Path.expand(path)

    cond do
      is_binary(env) and Path.expand(env) == path_expanded -> :env
      String.starts_with?(path_expanded, Path.expand(priv_dic_root)) -> :bundled
      true -> :system
    end
  end

  defp classify_source(:voice, path) do
    env = System.get_env("OPENJTALK_VOICE")
    priv_voice_dir = Application.app_dir(:open_jtalk_elixir, "priv/voices")
    path_expanded = Path.expand(path)

    cond do
      is_binary(env) and Path.expand(env) == path_expanded -> :env
      String.starts_with?(path_expanded, Path.expand(priv_voice_dir)) -> :bundled
      true -> :system
    end
  end
end
