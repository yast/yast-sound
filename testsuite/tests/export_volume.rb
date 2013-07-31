# encoding: utf-8

module Yast
  class ExportVolumeClient < Client
    def main
      # testedfiles: Sound.ycp
      Yast.include self, "testsuite.rb"

      Yast.import "Sound"

      @input = [[["Master", 80, false], ["CD", 90, false]]]
      TEST(lambda { Sound.ExportVolumeSettings(nil) }, [], nil)
      TEST(lambda { Sound.ExportVolumeSettings([]) }, [], nil)
      TEST(lambda { Sound.ExportVolumeSettings(@input) }, [], nil)

      nil
    end
  end
end

Yast::ExportVolumeClient.new.main
