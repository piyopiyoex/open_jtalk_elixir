defmodule OpenJTalk.OptionsTest do
  use ExUnit.Case, async: true

  alias OpenJTalk.Options

  test "validate!/1 returns valid options unchanged" do
    opts = [timbre: 0.1, pitch_shift: -2, rate: 1.2, gain: 3, playback_mode: :file]

    assert Options.validate!(opts) == opts
    assert OpenJTalk.validate_options!(opts) == opts
  end

  test "validate!/1 rejects unknown options" do
    assert_raise ArgumentError, "unknown option(s) for OpenJTalk: [:bogus]", fn ->
      Options.validate!(bogus: true)
    end
  end

  test "validate!/1 rejects invalid playback mode" do
    assert_raise ArgumentError, "invalid value for :playback_mode: :bogus", fn ->
      Options.validate!(playback_mode: :bogus)
    end
  end

  test "validate!/1 rejects invalid timeout" do
    for timeout <- [-1, 0] do
      assert_raise ArgumentError, "invalid value for :timeout: #{timeout}", fn ->
        Options.validate!(timeout: timeout)
      end
    end
  end

  test "validate!/1 rejects invalid option value types" do
    for {key, value} <- [
          timbre: :warm,
          pitch_shift: 1.5,
          rate: :fast,
          gain: "loud",
          voice: 123,
          dictionary: 123,
          out: 123
        ] do
      assert_raise ArgumentError, ~r/invalid value for #{inspect(key)}/, fn ->
        Options.validate!([{key, value}])
      end
    end
  end

  test "validate_for!/2 rejects options outside the function context" do
    assert_raise ArgumentError, "invalid option(s) for player: [:voice]", fn ->
      Options.validate_for!([voice: "/tmp/voice.htsvoice"], :player)
    end

    assert_raise ArgumentError, "invalid option(s) for synth: [:out]", fn ->
      Options.validate_for!([out: "/tmp/out.wav"], :synth)
    end

    assert Options.validate_for!([out: "/tmp/out.wav", playback_mode: :file], :say)
  end

  test "validate!/1 rejects non-keyword options" do
    assert_raise ArgumentError, "OpenJTalk options must be a keyword list", fn ->
      Options.validate!([:not_a_keyword])
    end
  end

  test "playback_mode/1 defaults to auto" do
    assert Options.playback_mode([]) == :auto
    assert Options.playback_mode(playback_mode: :stdin) == :stdin
  end

  test "normalize_timeout/1 defaults absent or invalid values" do
    assert Options.normalize_timeout(nil) == 20_000
    assert Options.normalize_timeout(:bad) == 20_000
    assert Options.normalize_timeout(0) == 20_000
    assert Options.normalize_timeout(123) == 123
  end

  test "clamp/3 limits numeric values" do
    assert Options.clamp(-1.0, 0.0, 1.0) == 0.0
    assert Options.clamp(0.5, 0.0, 1.0) == 0.5
    assert Options.clamp(2.0, 0.0, 1.0) == 1.0
  end
end
