# encoding: utf-8

#
# File:
#   sound_summary.ycp
#
# Module:
#   Sound
#
# Authors:
#   Dan Meszaros <dmeszar@suse.cz>
#
# Soud installation summary. returns list of already configured and not configured sound cards
#
module Yast
  class SoundSummaryClient < Client
    def main
      textdomain "sound"

      Yast.import "Sound"
      Yast.import "Progress"

      @progress_orig = Progress.set(false)
      Sound.Read(false)
      Progress.set(@progress_orig)
      Sound.Summary
    end
  end
end

Yast::SoundSummaryClient.new.main
