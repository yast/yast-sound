# encoding: utf-8

# File:
#   sound_auto.ycp
#
# Package:
#   Configuration of sound
#
# Summary:
#   Client for autoinstallation
#
# Authors:
#   Dan Meszaros <dmeszar@suse.cz>
#
# This is a client for autoinstallation. It takes its arguments,
# goes through the configuration and return the setting.
# Does not do any changes to the configuration.

# @param first a map of x settings
# @return [Boolean] success of operation
# @example map mm = $[ "FAIL_DELAY" : "77" ];
# @example map ret = WFM::CallModule ("x_auto", [ mm ]);
module Yast
  class SoundAutoClient < Client
    def main
      Yast.import "UI"
      textdomain "sound"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Sound auto started")

      Yast.import "Sound"
      Yast.import "Mode"
      Yast.import "Summary"
      Yast.import "Wizard"
      Yast.import "PulseAudio"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)


      Yast.include self, "sound/routines.rb"
      Yast.include self, "sound/volume.rb"

      # Create a  summary
      if @func == "Import"
        # detect the cards on the system, so we could write them
        # correctly:
        @param = UpdateCardsToTargetSystem(@param)
        @ret = Sound.Import(@param) && PulseAudio.Import(@param)
      # Create a  summary
      elsif @func == "Summary"
        @ret = Ops.add(Sound.Summary, PulseAudio.Summary)
        Builtins.y2milestone("Sound card configuration summary: %1", @ret)
      elsif @func == "GetModified"
        @ret = Sound.GetModified
      elsif @func == "SetModified"
        Sound.SetModified
        @ret = true
      # Reset configuration
      elsif @func == "Reset"
        Sound.Import({})
        PulseAudio.Reset
        @ret = {}
      # Change configuration (run AutoSequence) TODO
      elsif @func == "Change"
        # initialize to empty lists
        Sound.detected_cards = []
        Sound.unconfigured_cards = []

        @ret = WFM.CallFunction("sound", [])
      # Return required package list
      elsif @func == "Packages"
        @packages_to_install = []

        @reqmodules = Sound.RequiredKernelModules
        Builtins.foreach(@reqmodules) do |driver|
          req_packages = Sound.RequiredPackagesToInstall(driver)
          @packages_to_install = Convert.convert(
            Builtins.union(@packages_to_install, req_packages),
            :from => "list",
            :to   => "list <string>"
          )
        end 


        Builtins.y2milestone(
          "Collected packages to install: %1",
          @packages_to_install
        )

        @ret = { "install" => @packages_to_install }
      # Return actual state
      elsif @func == "Export"
        @ret = Sound.Export
        # add PulseAudio config if it's defined
        if PulseAudio.Enabled != nil
          @ret = Builtins.union(Convert.to_map(@ret), PulseAudio.Export)
        end
      elsif @func == "Read"
        PulseAudio.Read
        @ret = Sound.Read(false)
      # Write given settings
      elsif @func == "Write"
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        @settings = Sound.Export
        Sound.write_only = true
        @ret = WFM.CallFunction("sound_write", [@settings])
        Progress.set(@progress_orig)
        return deep_copy(@ret)
      else
        Builtins.y2error("Unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2milestone("ret=%1", @ret)
      Builtins.y2milestone("Sound auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end

    # During autoinstallation write, update the card's from control file
    # to match the detected cards from the current system
    def UpdateCardsToTargetSystem(settings)
      settings = deep_copy(settings)
      save_info = Ops.get_list(settings, "modules_conf", [])

      Sound.DetectHardware

      save_info = Builtins.maplist(save_info) do |saved_card|
        Builtins.foreach(Sound.detected_cards) do |e|
          mod = get_module(e)
          if Ops.get_string(saved_card, "module", "") ==
              Ops.get_string(mod, "name", "") &&
              Ops.get_string(e, "unique_key", "") != ""
            Ops.set(
              saved_card,
              "unique_key",
              Ops.get_string(e, "unique_key", "")
            )
            Ops.set(saved_card, "model", get_card_label(e))
          end
        end
        deep_copy(saved_card)
      end
      # ------------------------------------------------
      # now configure cards not included in control file

      Builtins.y2milestone(
        "configure_detected: %1",
        Ops.get_boolean(settings, "configure_detected", false)
      )

      if Ops.get_boolean(settings, "configure_detected", false)
        # Now update Sound data, so the configured cards can be recognized
        # Import is not used, because it would remove detected cards
        Sound.modules_conf = Builtins.eval(save_info)
        Sound.volume_settings = Builtins.eval(
          Sound.ImportVolumeSettings(
            Ops.get_list(settings, "volume_settings", [])
          )
        )

        Sound.UpdateUnconfiguredCards
        Builtins.foreach(Sound.unconfigured_cards) do |card|
          Sound.card_id = Builtins.size(save_info)
          card = add_common_options(card, Sound.card_id)
          card = add_alias(card, Sound.card_id)
          res = sound_volume(card, Sound.card_id, true, true, save_info)
          if Ops.get_symbol(res, "ui", :back) == :next
            save_info = Builtins.add(save_info, card)
            Builtins.y2milestone(
              "Added sound card '%1'",
              Ops.get_string(card, "model", "")
            )
          end
        end
        Ops.set(
          settings,
          "volume_settings",
          Sound.ExportVolumeSettings(Sound.volume_settings)
        )
      end
      Ops.set(settings, "modules_conf", Builtins.eval(save_info))
      deep_copy(settings)
    end
  end
end

Yast::SoundAutoClient.new.main
