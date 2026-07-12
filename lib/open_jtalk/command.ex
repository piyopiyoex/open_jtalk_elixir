defmodule OpenJTalk.Command do
  @moduledoc false
  # Small command-runner seam around MuonTrap.
  #
  # Tests can replace the runner with:
  #
  #     Application.put_env(:open_jtalk_elixir, :command_runner, MyRunner)
  #
  # where `MyRunner.cmd/3` has the same shape as `MuonTrap.cmd/3`.

  @spec run(binary(), [binary()], keyword()) :: {binary(), non_neg_integer()}
  def run(command, args, opts \\ [])
      when is_binary(command) and is_list(args) and is_list(opts) do
    command_runner().cmd(command, args, opts)
  end

  defp command_runner() do
    Application.get_env(:open_jtalk_elixir, :command_runner, OpenJTalk.Command.MuonTrap)
  end
end

defmodule OpenJTalk.Command.MuonTrap do
  @moduledoc false

  def cmd(command, args, opts), do: MuonTrap.cmd(command, args, opts)
end
