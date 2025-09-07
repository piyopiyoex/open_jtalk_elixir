defmodule OpenJTalkTest do
  use ExUnit.Case, async: true

  @tag :tmp_dir
  test "to_wav writes a wav", %{tmp_dir: tmp_dir} do
    out = Path.join(tmp_dir, "ojt_#{System.unique_integer([:positive])}.wav")
    assert {:ok, ^out} = OpenJTalk.to_wav("テストです。", out: out)
    assert File.exists?(out)
    assert {:ok, <<"RIFF", _::binary>>} = File.read(out)
    assert File.stat!(out).size > 44
  end

  test "to_binary returns a RIFF wav" do
    assert {:ok, <<"RIFF", _::binary>>} = OpenJTalk.to_binary("こんにちは")
  end
end
