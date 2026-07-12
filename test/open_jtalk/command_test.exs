defmodule OpenJTalk.CommandTest do
  use ExUnit.Case, async: false

  alias OpenJTalk.Command

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

  test "run/3 delegates to configured command runner" do
    assert {"ok", 0} = Command.run("echo", ["hello"], timeout: 123)

    assert_received {:cmd, "echo", ["hello"], [timeout: 123]}
  end

  defmodule Runner do
    def cmd(command, args, opts) do
      send(self(), {:cmd, command, args, opts})

      {"ok", 0}
    end
  end
end
