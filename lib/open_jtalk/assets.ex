defmodule OpenJTalk.Assets do
  @moduledoc false
  # Internal helpers for resolving the CLI, dictionary, and voice paths.
  # Recognizes OPENJTALK_CLI, OPENJTALK_DIC_DIR, and OPENJTALK_VOICE.

  @priv_bin Application.app_dir(:open_jtalk_elixir, "priv/bin/open_jtalk")
  @priv_dic_root Application.app_dir(:open_jtalk_elixir, "priv/dic")
  @priv_voice_dir Application.app_dir(:open_jtalk_elixir, "priv/voices")

  # Cache results to avoid repeated filesystem scans
  def resolve_bin() do
    case :persistent_term.get({__MODULE__, :bin}, :unknown) do
      :unknown ->
        env = System.get_env("OPENJTALK_CLI")

        path =
          cond do
            is_binary(env) and File.exists?(env) -> env
            File.exists?(@priv_bin) -> @priv_bin
            path = System.find_executable("open_jtalk") -> path
            true -> nil
          end

        if path,
          do: put(:bin, path),
          else: {:error, {:binary_missing, [@priv_bin, "$PATH:open_jtalk"]}}

      path when is_binary(path) ->
        {:ok, path}
    end
  end

  def resolve_dictionary(nil) do
    # Allow OPENJTALK_DIC_DIR or priv/dic/** with sys.dic
    case :persistent_term.get({__MODULE__, :dic}, :unknown) do
      :unknown ->
        env = System.get_env("OPENJTALK_DIC_DIR")

        dic =
          cond do
            is_binary(env) and File.exists?(Path.join(env, "sys.dic")) -> env
            path = find_sysdic_under(@priv_dic_root) -> path
            path = find_system_naist_jdic() -> path
            true -> nil
          end

        if dic, do: put(:dic, dic), else: {:error, {:dictionary_missing, @priv_dic_root}}

      path when is_binary(path) ->
        {:ok, path}
    end
  end

  def resolve_dictionary(path) when is_binary(path) do
    if File.exists?(Path.join(path, "sys.dic")),
      do: {:ok, path},
      else: {:error, {:dictionary_missing, path}}
  end

  def resolve_voice(nil) do
    case :persistent_term.get({__MODULE__, :voice}, :unknown) do
      :unknown ->
        env = System.get_env("OPENJTALK_VOICE")

        voice =
          cond do
            is_binary(env) and File.exists?(env) -> env
            path = pick_first_htsvoice(@priv_voice_dir) -> path
            path = find_system_voice() -> path
            true -> nil
          end

        if voice, do: put(:voice, voice), else: {:error, {:voice_missing, @priv_voice_dir}}

      path when is_binary(path) ->
        {:ok, path}
    end
  end

  def resolve_voice(path) when is_binary(path) do
    if File.exists?(path), do: {:ok, path}, else: {:error, {:voice_missing, path}}
  end

  def reset_cache() do
    for k <- [:bin, :dic, :voice], do: :persistent_term.erase({__MODULE__, k})
    :ok
  end

  # ---- helpers -----------------------------------------------------------------

  defp put(key, val) do
    :persistent_term.put({__MODULE__, key}, val)
    {:ok, val}
  end

  # also accept sys.dic directly under root (priv/dic/sys.dic)
  defp find_sysdic_under(root) do
    try do
      cond do
        not File.dir?(root) ->
          nil

        File.exists?(Path.join(root, "sys.dic")) ->
          root

        File.exists?(Path.join(root, "naist-jdic/sys.dic")) ->
          Path.join(root, "naist-jdic")

        true ->
          scan_subdirs_for_sysdic(root)
      end
    rescue
      _ -> nil
    end
  end

  defp scan_subdirs_for_sysdic(root) do
    root
    |> File.ls!()
    |> Enum.map(&Path.join(root, &1))
    |> Enum.find(fn dir -> File.dir?(dir) and File.exists?(Path.join(dir, "sys.dic")) end)
  end

  defp find_system_naist_jdic() do
    [
      "/var/lib/mecab/dic/open-jtalk/naist-jdic",
      "/usr/lib/x86_64-linux-gnu/mecab/dic/open-jtalk/naist-jdic",
      "/usr/lib/aarch64-linux-gnu/mecab/dic/open-jtalk/naist-jdic",
      "/usr/local/lib/mecab/dic/open-jtalk/naist-jdic",
      "/usr/lib/mecab/dic/open-jtalk/naist-jdic"
    ]
    |> Enum.find(&File.exists?(Path.join(&1, "sys.dic")))
  end

  defp pick_first_htsvoice(dir) do
    if File.dir?(dir) do
      dir |> Path.join("**/*.htsvoice") |> Path.wildcard() |> List.first()
    end
  end

  defp find_system_voice() do
    [
      "/usr/share/hts-voice/nitech-jp-atr503-m001/nitech_jp_atr503_m001.htsvoice",
      "/usr/local/share/hts-voice/nitech-jp-atr503-m001/nitech_jp_atr503_m001.htsvoice",
      "/usr/share/hts-voice/mei/mei_normal.htsvoice",
      "/usr/local/share/hts-voice/mei/mei_normal.htsvoice"
    ]
    |> Enum.find(&File.exists?/1)
  end
end
