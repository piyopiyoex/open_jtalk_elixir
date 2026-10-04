defmodule OpenJTalk do
  @external_resource "README.md"
  @moduledoc File.read!("README.md")
             |> String.split("<!-- MODULEDOC -->")
             |> Enum.fetch!(1)
             |> Kernel.<>("""
             Use `say/2` to synthesize and play speech, or `to_wav_binary/2` and
             `to_wav_file/2` when the generated audio is needed directly.

                 {:ok, wav} = OpenJTalk.to_wav_binary("こんにちは", rate: 1.1)
                 {:ok, path} = OpenJTalk.to_wav_file("こんにちは", out: "/tmp/greeting.wav")

             ## Options

             Synthesis functions accept `t:synth_option/0`. `say/2` also accepts
             `t:player_option/0`, and `to_wav_file/2` additionally accepts `:out`.

             Options are validated before work begins. Unknown keys, invalid playback
             modes, and non-positive timeouts raise `ArgumentError`; numeric synthesis
             values outside their supported ranges are clamped.

             ## Runtime assets

             Synthesis requires the `open_jtalk` executable, a dictionary containing
             `sys.dic`, and an HTS voice. Automatic lookup uses this order:

             1. `OPENJTALK_CLI`, `OPENJTALK_DICTIONARY_DIR`, or `OPENJTALK_VOICE`;
             2. the corresponding bundled asset under the application's `priv/` directory;
             3. a supported system installation.

             A per-call `:dictionary` or `:voice` option overrides automatic lookup for
             that request. Successful automatic resolutions are cached. After changing
             environment variables or moving assets at runtime, reset them before the
             next synthesis:

                 OpenJTalk.Assets.reset_cache()

             Use `info/0` to inspect each resolved path and whether it came from the
             environment, bundled assets, or the system.

             ## Errors and diagnostics

             Runtime failures return `{:error, reason}`. Common reasons include:

               * `{:binary_missing, paths}`, `{:dictionary_missing, path}`, or
                 `{:voice_missing, path}` when a required component cannot be resolved;
               * `{:open_jtalk_exit, status, output}` when synthesis fails;
               * `:no_player_found` or `{:player_failed, status, output}` when playback
                 fails.

             A command status may be `:timeout`. If synthesis succeeds but playback does
             not, use `to_wav_binary/2` to isolate the audio-player path and call `info/0`
             to see which player was selected.
             """)

  @typedoc "Voice color adjustment. Range: -0.8..0.8 (values are clamped)."
  @type timbre :: float()

  @typedoc "Pitch shift in semitones. Range: -24..24 (values are clamped)."
  @type pitch_shift :: -24..24

  @typedoc "Speaking rate multiplier. Range: 0.5..2.0 (values are clamped)."
  @type rate :: float()

  @typedoc "Output gain in dB. Typical useful range is about -20..20 (values are clamped)."
  @type gain :: number()

  @typedoc """
  Audio playback mode:

    * `:auto`  — prefer stdin when available; otherwise fall back to file playback
    * `:file`  — always use file-based playback
    * `:stdin` — stream WAV bytes via stdin (diskless); falls back to file if unsupported
  """
  @type playback_mode :: :auto | :file | :stdin

  @typedoc """
  Option accepted by playback functions.

    * `:playback_mode` - `:auto` (default), `:stdin`, or `:file`
    * `:timeout` - positive timeout in milliseconds; defaults to `20_000`
  """
  @type player_option ::
          {:timeout, pos_integer()}
          | {:playback_mode, playback_mode()}

  @typedoc """
  Option accepted by synthesis functions.

    * `:timbre` - voice-color offset, clamped to `-0.8..0.8`; defaults to `0.0`
    * `:pitch_shift` - semitone shift, clamped to `-24..24`; defaults to `0`
    * `:rate` - speaking speed, clamped to `0.5..2.0`; defaults to `1.0`
    * `:gain` - output gain in dB, clamped to `-20..20`; defaults to `0`
    * `:voice` - path to a `.htsvoice` file for this request
    * `:dictionary` - path to a directory containing `sys.dic` for this request
    * `:timeout` - positive timeout in milliseconds; defaults to `20_000`
  """
  @type synth_option ::
          {:timbre, timbre()}
          | {:pitch_shift, pitch_shift()}
          | {:rate, rate()}
          | {:gain, gain()}
          | {:voice, Path.t()}
          | {:dictionary, Path.t()}
          | {:timeout, pos_integer()}

  @typedoc "A synthesis option, or `:out` with the destination WAV path."
  @type wav_file_option :: synth_option() | {:out, Path.t()}

  @typedoc "Options accepted by `say/2` (synthesis + playback)."
  @type say_option :: player_option() | synth_option()

  @synth_option_keys [:timbre, :pitch_shift, :rate, :gain, :voice, :dictionary, :timeout]
  @player_option_keys [:timeout, :playback_mode]

  @typedoc "Entry describing a component path and where it came from."
  @type info_entry :: %{path: String.t() | nil, source: :env | :bundled | :system | :none}

  @typedoc "Return type of `info/0`."
  @type info_map :: %{
          bin: info_entry(),
          dictionary: info_entry(),
          voice: info_entry(),
          audio_player: info_entry()
        }

  @doc """
  Validate options for synthesis and playback.

  Allowed keys:
    * Synthesis: `:timbre`, `:pitch_shift`, `:rate`, `:gain`, `:voice`, `:dictionary`, `:timeout`
    * Playback:  `:playback_mode`, `:timeout`
    * Files:     `:out`

  Enforcement:
    * Unknown keys raise `ArgumentError`
    * `:playback_mode` must be one of `:auto | :file | :stdin` (if present)
    * `:timeout` must be a positive integer (if present)

  Returns the original `opts` on success.
  """
  @spec validate_options!(keyword) :: keyword
  def validate_options!(opts), do: OpenJTalk.Options.validate!(opts)

  @doc """
  Synthesize `text` to a WAV file.

  `:out` sets the destination path. Without it, a unique path is created in
  the system temporary directory.

  ## Example

      {:ok, path} = OpenJTalk.to_wav_file("こんにちは", out: "/tmp/greeting.wav")
  """
  @spec to_wav_file(binary, [wav_file_option()]) :: {:ok, Path.t()} | {:error, term()}
  def to_wav_file(text, opts \\ []) when is_binary(text) do
    opts = OpenJTalk.Options.validate_for!(opts, :wav_file)
    out = opts[:out] || OpenJTalk.Tempfile.tmp_path("wav")

    with {:ok, argv} <- OpenJTalk.Synth.args(out, opts),
         {:ok, txt, cleanup} <- OpenJTalk.Tempfile.write_tmp_text(text) do
      try do
        case OpenJTalk.Synth.run(argv ++ [txt], opts[:timeout]) do
          {:ok, _out} -> {:ok, out}
          {:error, _} = e -> e
        end
      after
        cleanup.()
      end
    end
  end

  @doc """
  Synthesize `text` and return RIFF/WAV bytes.

  ## Example

      {:ok, wav} = OpenJTalk.to_wav_binary("こんにちは", rate: 1.1)
  """
  @spec to_wav_binary(binary, [synth_option()]) :: {:ok, binary} | {:error, term()}
  def to_wav_binary(text, opts \\ []) when is_binary(text) do
    opts = OpenJTalk.Options.validate_for!(opts, :synth)

    OpenJTalk.Tempfile.with_tmp_path("wav", fn tmp ->
      with {:ok, _path} <- to_wav_file(text, Keyword.put(opts, :out, tmp)),
           {:ok, bin} <- File.read(tmp) do
        {:ok, bin}
      else
        {:error, _} = e -> e
      end
    end)
  end

  @doc """
  Play RIFF/WAV bytes already in memory.

  `:auto` and `:stdin` stream to a stdin-capable player when possible and fall
  back to a temporary file when stdin playback is unavailable. `:file` always
  uses a temporary file.
  """
  @spec play_wav_binary(iodata(), [player_option()]) :: :ok | {:error, term()}
  def play_wav_binary(wav_bytes, opts \\ []) do
    _ = OpenJTalk.Options.validate_for!(opts, :player)
    OpenJTalk.Player.play_wav_binary(wav_bytes, opts)
  end

  @doc "Play a WAV from a file path. See `play_wav_binary/2` for options."
  @spec play_wav_file(Path.t(), [player_option()]) :: :ok | {:error, term()}
  def play_wav_file(path, opts \\ []) do
    _ = OpenJTalk.Options.validate_for!(opts, :player)
    OpenJTalk.Player.play_wav_file(path, opts)
  end

  @doc """
  Synthesize `text` with Open JTalk and play it.

  The default `:auto` playback mode tries stdin first, then falls back to file
  playback. The generated WAV is not retained; use `to_wav_file/2` followed by
  `play_wav_file/2` when a persistent output file is required.

  ## Example

      :ok = OpenJTalk.say("こんにちは", pitch_shift: 2)
  """
  @spec say(binary, [say_option()]) :: :ok | {:error, term()}
  def say(text, opts \\ []) do
    opts = OpenJTalk.Options.validate_for!(opts, :say)
    mode = OpenJTalk.Options.playback_mode(opts)
    do_say(text, mode, opts)
  end

  defp do_say(text, :stdin, opts) do
    with {:ok, wav} <- to_wav_binary(text, synth_options(opts)) do
      OpenJTalk.Player.play_wav_binary(wav, player_options(opts))
    end
  end

  defp do_say(text, :file, opts) do
    OpenJTalk.Tempfile.with_tmp_path("wav", fn out ->
      case to_wav_file(text, opts |> synth_options() |> Keyword.put_new(:out, out)) do
        {:ok, path} -> OpenJTalk.Player.play_wav_file(path, player_options(opts))
        {:error, _} = e -> e
      end
    end)
  end

  # :auto prefers stdin path (Player will fall back to file internally as needed)
  defp do_say(text, :auto, opts), do: do_say(text, :stdin, opts)

  defp synth_options(opts), do: Keyword.take(opts, @synth_option_keys)
  defp player_options(opts), do: Keyword.take(opts, @player_option_keys)

  @doc """
  Return the resolved executable, dictionary, voice, and audio player.

  Each entry includes its path and whether it came from an environment
  variable, bundled assets, the system, or no available source.
  """
  @spec info() :: {:ok, info_map()}
  def info() do
    OpenJTalk.Info.info()
  end
end
