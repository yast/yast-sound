# encoding: utf-8

# File:	clients/sound_proposal.ycp
# Package:	Sound configuration
# Summary:	Proposal function dispatcher
# Authors:	Dan Meszaros <dmeszar@suse.cz>
#		Ladislav Slezak <lslezak@suse.cz>
#
# Proposal function dispatcher for sound configuration.
module Yast
  class SoundProposalClient < Client
    def main
      Yast.import "UI"

      textdomain "sound"

      Yast.import "Sound"
      Yast.import "Progress"
      Yast.import "PulseAudio"

      Sound.installation = true

      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}

      # Make proposal for installation/configuration...
      if @func == "MakeProposal"
        @force_reset = Ops.get_boolean(@param, "force_reset", false)

        if @force_reset
          Sound.ForceReset
          PulseAudio.Reset
        end

        # Do not show any progress during Read()
        @progress_orig = Progress.set(false)

        UI.OpenDialog(VBox(Label(_("Detecting sound cards..."))))

        Sound.Propose
        PulseAudio.Propose

        UI.CloseDialog

        Progress.set(@progress_orig)

        @proposal = Ops.add(Sound.Summary, PulseAudio.Summary)

        # Fill return map
        @ret = {
          "preformatted_proposal" => @proposal,
          "warning"               => nil, #_("Sound cards."),
          "warning_level"         => nil
        } #`notice
      # Run an interactive workflow
      elsif @func == "AskUser"
        @has_next = Ops.get_boolean(@param, "has_next", false)

        Sound.installation = true

        @sequence = WFM.CallFunction("sound", [])

        # Fill return map
        @ret = { "workflow_sequence" => @sequence }
      # Return human readable titles for the proposal
      elsif @func == "Description"
        # Fill return map
        @ret =
          # section name in proposal dialog
          {
            "rich_text_title" => _("Sound"),
            # section name in proposal - menu item
            "menu_title"      => _(
              "&Sound"
            ),
            "id"              => "sound_conf"
          }
      elsif @func == "Write"
        Sound.Write
        PulseAudio.Write
      end

      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::SoundProposalClient.new.main
