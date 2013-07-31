# encoding: utf-8

#
# File:
#   card_wizard.ycp
#
# Module:
#   Sound
#
# Authors:
#   Dan Meszaros <dmeszar@suse.cz>
#
# One sound card setup wizard.
#
module Yast
  module SoundCardWizardInclude
    def initialize_sound_card_wizard(include_target)
      Yast.import "UI"

      Yast.import "Sequencer"
      Yast.import "Sound"


      Yast.include include_target, "sound/ui.rb"
      Yast.include include_target, "sound/options.rb"
      Yast.include include_target, "sound/volume.rb"
      Yast.include include_target, "sound/routines.rb" # add_common_options, add_alias
    end

    # wrapper function for running first card config dialog (There will be shown
    # possibilities for next configuration steps (quick/normal/expert)
    def _showName(card_id, flags)
      modelname = Ops.get_string(Sound.save_entry, "model", "")
      modname = Ops.get_string(Sound.save_entry, "module", "")

      res = DisplayName(
        modelname,
        Ops.get_string(Sound.save_entry, "alias", ""),
        card_id,
        flags
      )

      ui = Ops.get_symbol(res, "ui", :back)

      Thinkpad600E_cs4236_hack(card_id) if ui != :back && ui != :abort

      ui
    end

    # wrapper function for running Options dialog (during expert configuration)
    def _options(card_id)
      res = sound_options(Sound.save_entry)
      ui = Ops.get_symbol(res, "ui", :back)
      if ui == :next
        Sound.save_entry = Ops.get_map(res, "return", {})
        Sound.save_entry = add_common_options(Sound.save_entry, card_id)
      end
      ui
    end

    # wrapper function for quick configuration (just modprobe)
    def _quick(card_id, finish, save_info)
      save_info = deep_copy(save_info)
      res = sound_volume(Sound.save_entry, card_id, finish, true, save_info)
      ui = Ops.get_symbol(res, "ui", :back)
      ui
    end

    # wrapper function for normal configuration (modprobe + volume setting)
    def _volume(card_id, finish, save_info)
      save_info = deep_copy(save_info)
      res = sound_volume(Sound.save_entry, card_id, finish, false, save_info)
      ui = Ops.get_symbol(res, "ui", :back)
      ui
    end


    # Wizard steps: 1. displayname<br>
    # 2. modprobe and volume settings
    # @param [Hash] card_entry the card to configure
    # @param [Fixnum] card_id index of configured car
    # @param [Fixnum] flags defines which radioboxes has to be enabled
    #		(0x1 - first, 0x2 second, 0x4 third...)
    # @param [Boolean] finish true if no complex dialog is to be called
    #		(then the popup "Config will be saved.." will appear)
    # @return [Hash] with save info, as required by sound_write for one cards
    def OneCardWizard(card_entry, card_id, flags, finish, save_info)
      card_entry = deep_copy(card_entry)
      save_info = deep_copy(save_info)
      aliases = {
        "name"      => lambda { _showName(card_id, flags) },
        "options"   => lambda { _options(card_id) },
        "volume"    => lambda { _volume(card_id, finish, save_info) },
        "optVolume" => lambda { _volume(card_id, finish, save_info) },
        "quick"     => lambda { _quick(card_id, finish, save_info) }
      }

      sequence = {
        "ws_start"  => "name",
        "name"      => {
          :quick   => "quick",
          :skip    => :back,
          :next    => "volume",
          :options => "options",
          :abort   => :abort
        },
        "options"   => { :next => "optVolume", :abort => :abort },
        "volume"    => { :next => :next, :abort => :abort },
        "optVolume" => { :next => :next, :abort => :abort },
        "quick"     => { :next => :next, :abort => :abort }
      }
      Sound.save_entry = Builtins.eval(card_entry)
      Sound.save_entry = add_common_options(Sound.save_entry, card_id)
      Sound.save_entry = add_alias(Sound.save_entry, card_id)

      ui = Sequencer.Run(aliases, sequence)
      { "ui" => ui, "return" => Sound.save_entry }
    end
  end
end
