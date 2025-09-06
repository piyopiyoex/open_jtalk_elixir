ExUnit.start()

if System.get_env("OPENJTALK_AUDIO_TESTS") != "1" do
  ExUnit.configure(exclude: [:audio])
end
