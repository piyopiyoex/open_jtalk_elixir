defmodule OpenJTalk.InfoTest do
  use ExUnit.Case, async: true

  test "info/0 returns a well-formed map" do
    assert {:ok, info} = OpenJTalk.info()

    assert %{
             bin: %{path: bin_path, source: bin_src},
             dictionary: %{path: dic_path, source: dic_src},
             voice: %{path: voice_path, source: voice_src},
             audio_player: %{path: ap_path, source: ap_src}
           } = info

    assert (is_binary(bin_path) and bin_path != "") or is_nil(bin_path)
    assert bin_src in [:env, :bundled, :system, :none]

    assert (is_binary(dic_path) and dic_path != "") or is_nil(dic_path)
    assert dic_src in [:env, :bundled, :system, :none]

    assert (is_binary(voice_path) and voice_path != "") or is_nil(voice_path)
    assert voice_src in [:env, :bundled, :system, :none]

    assert ap_src in [:system, :none]
    assert is_binary(ap_path) or is_nil(ap_path)
  end
end
