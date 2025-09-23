#!/usr/bin/env elixir
#
# fetch_sources.exs — fetch archives into vendor/, extract sources, and install assets.
#
# Usage: elixir scripts/fetch_sources.exs [src|assets|all]
#
# Env:
#   OPENJTALK_ROOT_DIR      (default: repo root)
#   OPENJTALK_FETCH_JOBS    (default: 2× schedulers)
#   OPENJTALK_FETCH_RETRIES (default: 3)
#   OPENJTALK_FETCH_VERBOSE (0=quiet, 1=normal [default], 2=verbose)
#
defmodule Main do
  # ---------------- centralized names ----------------
  @config_sub_file "config.sub"
  @config_guess_file "config.guess"

  @openjtalk_tgz_file "open_jtalk-1.11.tar.gz"
  @hts_tgz_file "hts_engine_API-1.10.tar.gz"
  @mecab_tgz_file "mecab-0.996.tar.gz"

  @dic_tgz_file "open_jtalk_dic_utf_8-1.11.tar.gz"
  @mei_zip_file "MMDAgent_Example-1.8.zip"

  @openjtalk_dir "open_jtalk"
  @hts_dir "hts_engine"
  @mecab_dir "mecab"

  @mei_voice_file "mei_normal.htsvoice"

  # filename => url
  @gnuconfig_urls %{
    @config_sub_file => "https://raw.githubusercontent.com/spack/gnuconfig/master/config.sub",
    @config_guess_file => "https://raw.githubusercontent.com/spack/gnuconfig/master/config.guess"
  }

  @src_urls %{
    @openjtalk_tgz_file =>
      "https://sourceforge.net/projects/open-jtalk/files/Open%20JTalk/open_jtalk-1.11/open_jtalk-1.11.tar.gz/download",
    @hts_tgz_file =>
      "https://sourceforge.net/projects/hts-engine/files/hts_engine%20API/hts_engine_API-1.10/hts_engine_API-1.10.tar.gz/download",
    @mecab_tgz_file => "https://deb.debian.org/debian/pool/main/m/mecab/mecab_0.996.orig.tar.gz"
  }

  @asset_urls %{
    @dic_tgz_file =>
      "https://sourceforge.net/projects/open-jtalk/files/Dictionary/open_jtalk_dic-1.11/open_jtalk_dic_utf_8-1.11.tar.gz/download",
    @mei_zip_file =>
      "https://sourceforge.net/projects/mmdagent/files/MMDAgent_Example/MMDAgent_Example-1.8/MMDAgent_Example-1.8.zip/download"
  }

  def main(argv \\ System.argv()) do
    cfg = read_config(argv)

    File.mkdir_p!(cfg.vendor)
    File.mkdir_p!(cfg.priv_dic)
    File.mkdir_p!(cfg.priv_voices)

    need_src? =
      case cfg.mode do
        "src" -> not sources_ready?(cfg)
        "all" -> not sources_ready?(cfg)
        _ -> false
      end

    need_assets? =
      case cfg.mode do
        "assets" -> not assets_ready?(cfg)
        "all" -> not assets_ready?(cfg)
        _ -> false
      end

    cond do
      cfg.mode == "src" and not need_src? ->
        qlog("sources present; skipping src")
        System.halt(0)

      cfg.mode == "assets" and not need_assets? ->
        qlog("assets present; skipping assets")
        System.halt(0)

      cfg.mode == "all" and not need_src? and not need_assets? ->
        qlog("everything present; nothing to do")
        System.halt(0)

      true ->
        :ok
    end

    {src_jobs, asset_jobs} = build_download_jobs(cfg.vendor)

    jobs =
      case cfg.mode do
        "src" -> src_jobs
        "assets" -> asset_jobs
        "all" -> src_jobs ++ asset_jobs
        other -> abort_with_message("Unknown mode: #{other} (use src|assets|all)")
      end

    download_concurrency = min(cfg.jobs, min(length(jobs), 6))
    extract_concurrency = min(cfg.jobs, 3)

    qlog("fetch (#{cfg.mode}) starting, jobs=#{download_concurrency}, retries=#{cfg.retries}")

    if cfg.mode in ["src", "all"] and need_src? do
      unless gnuconfig_ready?(cfg.vendor) do
        prefetch_gnuconfig!(cfg.vendor, cfg.retries)
      end
    end

    dl_result =
      run_tasks_concurrently(jobs, download_concurrency, fn {url, dest} ->
        download_file(url, dest, cfg.retries, cfg.retries)
      end)

    case dl_result do
      {:ok, _} -> :ok
      {:error, es} -> abort_with_message("One or more downloads failed:\n" <> Enum.join(es, "\n"))
    end

    if cfg.mode in ["src", "all"] do
      if need_src? do
        tgzs = list_source_tarballs(cfg.vendor)

        verify_result =
          run_tasks_concurrently(tgzs, min(2, cfg.jobs), fn tgz ->
            case verify_tarball(tgz) do
              :ok ->
                :ok

              {:error, _} ->
                base = Path.basename(tgz)
                url = Map.fetch!(@src_urls, base)
                _ = File.rm(tgz)

                with :ok <- download_file(url, tgz, cfg.retries, cfg.retries),
                     :ok <- verify_tarball(tgz) do
                  :ok
                else
                  {:error, msg} -> {:error, "re-download failed for #{base}: #{msg}"}
                  other -> {:error, "re-verify failed for #{base}: #{inspect(other)}"}
                end
            end
          end)

        case verify_result do
          {:ok, _} -> :ok
          {:error, es} -> abort_with_message("Verification failed:\n" <> Enum.join(es, "\n"))
        end

        extract_targets = [
          {Path.join(cfg.vendor, @openjtalk_tgz_file), Path.join(cfg.vendor, @openjtalk_dir)},
          {Path.join(cfg.vendor, @hts_tgz_file), Path.join(cfg.vendor, @hts_dir)},
          {Path.join(cfg.vendor, @mecab_tgz_file), Path.join(cfg.vendor, @mecab_dir)}
        ]

        qlog("extracting sources...")

        ex_result =
          run_tasks_concurrently(extract_targets, extract_concurrency, fn {tgz, dir} ->
            qlog("extracting #{Path.basename(tgz)} -> #{dir}")
            extract_tarball(tgz, dir)
          end)

        case ex_result do
          {:ok, _} -> qlog("extracting sources done")
          {:error, es} -> abort_with_message("Extraction failed:\n" <> Enum.join(es, "\n"))
        end
      else
        qlog("sources present; skipping extraction")
      end
    end

    if cfg.mode in ["assets", "all"] do
      if need_assets? do
        qlog("installing assets...")

        dict_tgz = Path.join(cfg.vendor, @dic_tgz_file)
        qlog("installing dictionary: #{Path.basename(dict_tgz)} -> #{cfg.priv_dic}")

        case install_dictionary_archive(dict_tgz, cfg.priv_dic) do
          :ok -> qlog("dictionary installed -> #{cfg.priv_dic} (ok)")
          {:error, m} -> abort_with_message("Dictionary install failed: " <> m)
        end

        voice_zip = Path.join(cfg.vendor, @mei_zip_file)
        voice_dst = Path.join(cfg.priv_voices, @mei_voice_file)
        qlog("installing voice: #{Path.basename(voice_zip)} -> #{voice_dst}")

        case install_voice_zip(voice_zip, voice_dst) do
          :ok -> qlog("voice installed -> #{voice_dst} (ok)")
          {:error, m} -> abort_with_message("Voice install failed: " <> m)
        end

        qlog("installing assets done")
      else
        qlog("assets present; skipping install")
      end
    end

    qlog("fetch (#{cfg.mode}) done")
  end

  defp read_config(argv) do
    mode = (List.first(argv) || "all") |> String.downcase()

    root =
      System.get_env("OPENJTALK_ROOT_DIR") ||
        Path.expand(Path.join(Path.dirname(__ENV__.file), ".."))

    %{
      mode: mode,
      vendor: Path.join(root, "vendor"),
      priv_dic: Path.join(root, "priv/dic"),
      priv_voices: Path.join(root, "priv/voices"),
      jobs:
        (System.get_env("OPENJTALK_FETCH_JOBS") || "#{System.schedulers_online() * 2}")
        |> String.to_integer()
        |> max(1),
      retries:
        (System.get_env("OPENJTALK_FETCH_RETRIES") || "3")
        |> String.to_integer()
        |> max(0),
      verbose:
        case Integer.parse(System.get_env("OPENJTALK_FETCH_VERBOSE") || "1") do
          {n, _} -> n |> max(0) |> min(2)
          :error -> 1
        end
    }
  end

  defp qlog(msg), do: log(msg, 1)
  defp vlog(msg), do: log(msg, 2)

  defp log(msg, lvl) do
    verbose =
      case Integer.parse(System.get_env("OPENJTALK_FETCH_VERBOSE") || "1") do
        {n, _} -> n |> max(0) |> min(2)
        :error -> 1
      end

    if verbose >= lvl, do: IO.puts(:stderr, "[fetch_sources.exs] " <> msg)
  end

  defp abort_with_message(msg) do
    IO.puts(:stderr, "[fetch_sources.exs] ERROR: " <> msg)
    System.halt(1)
  end

  defp run_tasks_concurrently(items, max_concurrency, fun) do
    errors =
      items
      |> Task.async_stream(fun,
        max_concurrency: max_concurrency,
        timeout: :infinity,
        ordered: false
      )
      |> Enum.flat_map(fn
        {:ok, :ok} -> []
        {:ok, other} when other in [:ok, nil] -> []
        {:ok, {:error, msg}} -> [msg]
        {:ok, msg} when is_binary(msg) -> [msg]
        {:exit, reason} -> ["task exit: #{inspect(reason)}"]
        {:error, reason} -> ["task error: #{inspect(reason)}"]
      end)

    if errors == [], do: {:ok, :done}, else: {:error, errors}
  end

  defp download_file(url, dest, retries_left, total_retries) do
    try do
      cond do
        File.exists?(dest) and File.stat!(dest).size > 0 ->
          vlog("already present #{Path.basename(dest)}")
          :ok

        true ->
          qlog("downloading #{Path.basename(dest)}")

          {out, status} =
            System.cmd(
              "curl",
              [
                "-LfsS",
                "--retry",
                "8",
                "--retry-all-errors",
                "--retry-connrefused",
                "--retry-delay",
                "1",
                "--retry-max-time",
                "120",
                "--connect-timeout",
                "10",
                "--max-time",
                "0",
                "-C",
                "-",
                url,
                "-o",
                dest
              ],
              stderr_to_stdout: true
            )

          case status do
            0 ->
              :ok

            _ when retries_left > 0 ->
              vlog(
                "retrying #{Path.basename(dest)} (left=#{retries_left}) -- #{String.trim(out)}"
              )

              _ = File.rm(dest)
              backoff_ms = trunc(:math.pow(2, max(total_retries, 1) - retries_left) * 500)
              Process.sleep(backoff_ms)
              download_file(url, dest, retries_left - 1, total_retries)

            _ ->
              {:error, "curl failed (#{status}) for #{url}\n#{out}"}
          end
      end
    rescue
      e -> {:error, "exception while downloading #{url}: #{Exception.message(e)}"}
    end
  end

  defp verify_tarball(tgz) do
    if File.exists?(tgz) do
      {_out, status} = System.cmd("tar", ["-tzf", tgz], stderr_to_stdout: true)
      if status == 0, do: :ok, else: {:error, :invalid}
    else
      {:error, :missing}
    end
  end

  defp extract_tarball(tgz, dest) do
    try do
      unless File.exists?(tgz), do: {:error, "archive missing: #{tgz}"}
      needs_extract? = not File.dir?(dest) or (File.dir?(dest) and File.ls!(dest) == [])

      if needs_extract? do
        File.mkdir_p!(dest)
        {out, status} = System.cmd("tar", ["-xzf", tgz, "-C", dest], stderr_to_stdout: true)
        if status == 0, do: :ok, else: {:error, "tar failed for #{tgz}\n#{out}"}
      else
        :ok
      end
    rescue
      e -> {:error, "exception while extracting #{tgz}: #{Exception.message(e)}"}
    end
  end

  defp install_dictionary_archive(tgz, dest_dir) do
    try do
      unless File.exists?(tgz), do: {:error, "archive missing: #{tgz}"}

      tmp = create_tmp_dir!()
      {out, status} = System.cmd("tar", ["-xzf", tgz, "-C", tmp], stderr_to_stdout: true)
      if status != 0, do: {:error, "tar failed: #{out}"}, else: :ok

      root =
        File.ls!(tmp)
        |> Enum.map(&Path.join(tmp, &1))
        |> Enum.find(fn p ->
          File.dir?(p) and String.contains?(Path.basename(p), "open_jtalk_dic")
        end) ||
          tmp

      File.rm_rf(dest_dir)
      File.mkdir_p!(dest_dir)

      for entry <- File.ls!(root) do
        src = Path.join(root, entry)
        System.cmd("cp", ["-R", src, dest_dir])
      end

      if File.exists?(Path.join(dest_dir, "sys.dic")), do: :ok, else: {:error, "sys.dic missing"}
    rescue
      e -> {:error, "exception while installing dictionary: #{Exception.message(e)}"}
    end
  end

  defp install_voice_zip(zip, dest_voice) do
    try do
      unless File.exists?(zip), do: {:error, "zip missing: #{zip}"}

      tmp = create_tmp_dir!()
      {out, status} = System.cmd("unzip", ["-q", "-o", zip, "-d", tmp], stderr_to_stdout: true)
      if status != 0, do: {:error, "unzip failed: #{out}"}, else: :ok

      candidate = Path.join(tmp, "MMDAgent_Example-1.8/Voice/mei/#{@mei_voice_file}")

      src =
        cond do
          File.exists?(candidate) ->
            candidate

          true ->
            case System.cmd("bash", [
                   "-lc",
                   "shopt -s globstar nullglob; printf '%s\n' " <>
                     ~s{"#{tmp}/**/#{@mei_voice_file}"}
                 ]) do
              {paths, 0} ->
                paths
                |> String.split("\n", trim: true)
                |> List.first()

              _ ->
                nil
            end
        end

      if is_nil(src), do: {:error, "#{@mei_voice_file} not found"}, else: :ok

      File.mkdir_p!(Path.dirname(dest_voice))
      File.cp!(src, dest_voice)
      :ok
    rescue
      e -> {:error, "exception while installing voice: #{Exception.message(e)}"}
    end
  end

  defp dir_nonempty?(path) when is_binary(path),
    do: File.dir?(path) and match?([_ | _], File.ls!(path))

  defp sources_ready?(cfg) do
    dir_nonempty?(Path.join(cfg.vendor, @openjtalk_dir)) and
      dir_nonempty?(Path.join(cfg.vendor, @hts_dir)) and
      dir_nonempty?(Path.join(cfg.vendor, @mecab_dir))
  rescue
    _ -> false
  end

  defp assets_ready?(cfg) do
    File.exists?(Path.join(cfg.priv_dic, "sys.dic")) and
      File.exists?(Path.join(cfg.priv_voices, @mei_voice_file))
  end

  defp gnuconfig_ready?(vendor) do
    sub = Path.join(vendor, @config_sub_file)
    gue = Path.join(vendor, @config_guess_file)

    File.exists?(sub) and File.stat!(sub).size > 0 and
      File.exists?(gue) and File.stat!(gue).size > 0
  rescue
    _ -> false
  end

  defp prefetch_gnuconfig!(vendor, retries) do
    qlog("prefetching gnuconfig (config.sub/guess)")

    jobs = for {fname, url} <- @gnuconfig_urls, do: {url, Path.join(vendor, fname)}

    result =
      run_tasks_concurrently(jobs, 2, fn {url, dest} ->
        case download_file(url, dest, retries, retries) do
          :ok ->
            if File.exists?(dest), do: File.chmod(dest, 0o755)
            :ok

          {:error, msg} ->
            {:error, msg}
        end
      end)

    case result do
      {:ok, _} -> :ok
      {:error, es} -> abort_with_message("gnuconfig fetch failed:\n" <> Enum.join(es, "\n"))
    end
  end

  defp build_download_jobs(vendor) do
    src_jobs = for {fname, url} <- @src_urls, do: {url, Path.join(vendor, fname)}
    asset_jobs = for {fname, url} <- @asset_urls, do: {url, Path.join(vendor, fname)}
    {src_jobs, asset_jobs}
  end

  defp list_source_tarballs(vendor) do
    Map.keys(@src_urls) |> Enum.map(&Path.join(vendor, &1))
  end

  defp create_tmp_dir!() do
    base =
      Path.join(System.tmp_dir!(), "fs_" <> Integer.to_string(System.unique_integer([:positive])))

    File.mkdir_p!(base)
    base
  end
end

Main.main()
