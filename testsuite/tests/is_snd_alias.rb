# encoding: utf-8

module Yast
  class IsSndAliasClient < Client
    def main
      Yast.import "UI"
      # testedfiles: Sound.ycp sound/routines.ycp
      Yast.include self, "testsuite.rb"

      # initialization is needed because module Sound imports the module Arch
      # and Arch module does a SCR call .probe.system
      @READ = {
        "target" => { "size" => -1, "tmpdir" => "/tmp" },
        "probe"  => { "system" => [] }
      }

      TESTSUITE_INIT([@READ], nil)

      Yast.import "Sound"
      Yast.include self, "sound/routines.rb"

      Builtins.foreach(
        [true, false] # check for both alsa and oss behaviour
      ) do |snd|
        Sound.use_alsa = snd
        TEST(lambda { is_snd_alias("") }, [], nil)
        TEST(lambda { is_snd_alias("snd-card-0") }, [], nil)
        TEST(lambda { is_snd_alias("snd-card-16") }, [], nil)
        TEST(lambda { is_snd_alias("snd-card-emu10k1") }, [], nil)
        TEST(lambda { is_snd_alias("snd-card-0a") }, [], nil)
        TEST(lambda { is_snd_alias("snd-card-a0") }, [], nil)
        TEST(lambda { is_snd_alias("sound-slot-1") }, [], nil)
        TEST(lambda { is_snd_alias("sound-slot-117") }, [], nil)
        TEST(lambda { is_snd_alias("sound-slot-0a") }, [], nil)
        TEST(lambda { is_snd_alias("sound-slot-asdf") }, [], nil)
        TEST(lambda { is_snd_alias("  sound-slot-0") }, [], nil)
      end

      nil
    end
  end
end

Yast::IsSndAliasClient.new.main
