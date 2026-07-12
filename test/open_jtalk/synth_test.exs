defmodule OpenJTalk.SynthTest do
  use ExUnit.Case, async: false

  alias OpenJTalk.Synth

  setup do
    original_runner = Application.get_env(:open_jtalk_elixir, :command_runner)
    Application.put_env(:open_jtalk_elixir, :command_runner, __MODULE__.Runner)

    on_exit(fn ->
      if original_runner do
        Application.put_env(:open_jtalk_elixir, :command_runner, original_runner)
      else
        Application.delete_env(:open_jtalk_elixir, :command_runner)
      end
    end)
  end

  test "run/2 executes open_jtalk through the command runner" do
    assert {:ok, "ok"} = Synth.run(["/tmp/open_jtalk", "-x", "/tmp/dic"], 123)

    assert_received {:cmd, "/tmp/open_jtalk", ["-x", "/tmp/dic"], opts}
    assert Keyword.fetch!(opts, :stderr_to_stdout)
    assert Keyword.fetch!(opts, :timeout) == 123
    assert {"LC_ALL", "C"} in Keyword.fetch!(opts, :env)
  end

  test "run/2 trims failed command output" do
    Process.put(:command_result, {"failure\n", 2})

    assert {:error, {:open_jtalk_exit, 2, "failure"}} =
             Synth.run(["/tmp/open_jtalk", "-x", "/tmp/dic"], 123)
  end

  defmodule Runner do
    def cmd(command, args, opts) do
      send(self(), {:cmd, command, args, opts})

      Process.get(:command_result, {"ok", 0})
    end
  end
end
