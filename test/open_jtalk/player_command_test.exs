defmodule OpenJTalk.PlayerCommandTest do
  use ExUnit.Case, async: false

  alias OpenJTalk.Player

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    original_path = System.get_env("PATH")
    original_runner = Application.get_env(:open_jtalk_elixir, :command_runner)
    player = Path.join(tmp_dir, "aplay")

    File.write!(player, "#!/bin/sh\nexit 0\n")
    File.chmod!(player, 0o755)
    System.put_env("PATH", tmp_dir)
    Application.put_env(:open_jtalk_elixir, :command_runner, __MODULE__.Runner)

    on_exit(fn ->
      if original_path,
        do: System.put_env("PATH", original_path),
        else: System.delete_env("PATH")

      if original_runner,
        do: Application.put_env(:open_jtalk_elixir, :command_runner, original_runner),
        else: Application.delete_env(:open_jtalk_elixir, :command_runner)
    end)

    :ok
  end

  test "file playback delegates to the command runner" do
    assert :ok = Player.play_wav_file("/tmp/example.wav", timeout: 123)

    assert_received {:cmd, "aplay", ["-q", "/tmp/example.wav"], opts}
    assert Keyword.fetch!(opts, :timeout) == 123
    assert Keyword.fetch!(opts, :stderr_to_stdout)
  end

  test "file playback reports command failures" do
    Process.put(:command_results, [{"device unavailable\n", 2}])

    assert {:error, {:player_failed, 2, "device unavailable"}} =
             Player.play_wav_file("/tmp/example.wav")
  end

  test "stdin playback sends WAV bytes through the command runner" do
    wav = ["RIFF", <<1, 2, 3>>]

    assert :ok = Player.play_wav_binary(wav, playback_mode: :stdin)

    assert_received {:cmd, "aplay", ["-q", "-"], opts}
    assert Keyword.fetch!(opts, :stdin) == IO.iodata_to_binary(wav)
  end

  test "unsupported stdin falls back to a cleaned-up temporary file" do
    Process.put(:command_results, [:argument_error, {"", 0}])

    assert :ok = Player.play_wav_binary("RIFFdata", playback_mode: :stdin)

    assert_received {:cmd, "aplay", ["-q", "-"], _opts}
    assert_received {:cmd, "aplay", ["-q", path], opts}
    refute Keyword.has_key?(opts, :stdin)
    refute File.exists?(path)
  end

  defmodule Runner do
    def cmd(command, args, opts) do
      send(self(), {:cmd, command, args, opts})

      case Process.get(:command_results, []) do
        [:argument_error | rest] ->
          Process.put(:command_results, rest)
          raise ArgumentError, "stdin is unsupported"

        [result | rest] ->
          Process.put(:command_results, rest)
          result

        [] ->
          {"", 0}
      end
    end
  end
end
