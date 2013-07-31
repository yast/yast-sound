# encoding: utf-8

module Yast
  class IsaUniqClient < Client
    def main
      Yast.import "UI"
      # testedfiles: Sound.ycp sound/routines.ycp
      Yast.include self, "testsuite.rb"
      @READ_I = { "target" => { "size" => -1, "tmpdir" => "/tmp" } }

      TESTSUITE_INIT([@READ_I], nil)
      Yast.include self, "sound/routines.rb"

      TEST(lambda { isa_uniq }, [], nil)

      nil
    end
  end
end

Yast::IsaUniqClient.new.main
