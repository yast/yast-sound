# encoding: utf-8

module Yast
  class ImportVolumeClient < Client
    def main
      # testedfiles: Sound.ycp
      Yast.include self, "testsuite.rb"

      Yast.import "Sound"


      # Important: import of the new and the old format must produce the same output!

      @input_old_format = [[["Master", 80, false], ["CD", 90, false]]]

      TEST(lambda { Sound.ImportVolumeSettings(nil) }, [], nil)
      TEST(lambda { Sound.ImportVolumeSettings([]) }, [], nil)
      TEST(lambda { Sound.ImportVolumeSettings(@input_old_format) }, [], nil)

      @input_new_format = [
        [
          { "mute" => false, "name" => "Master", "volume" => 80 },
          { "mute" => false, "name" => "CD", "volume" => 90 }
        ]
      ]

      TEST(lambda { Sound.ImportVolumeSettings(@input_new_format) }, [], nil)

      nil
    end
  end
end

Yast::ImportVolumeClient.new.main
