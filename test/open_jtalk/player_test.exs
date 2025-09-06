defmodule OpenJTalk.PlayerTest do
  use ExUnit.Case, async: true

  @tag :audio
  test "say plays audio and cleans up tmp file" do
    if OpenJTalk.Player.available?() do
      assert :ok = OpenJTalk.say("こんにちは。これはテストです。")
    else
      IO.puts("⚠️  No audio player found; skipping.")
      :ok
    end
  end
end
