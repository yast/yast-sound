# encoding: utf-8

# File:	include/sound/wizards.ycp
# Package:	Configuration of sound cards
# Summary:	Wizards definitions
# Authors:	Dan Vesely <dan@suse.cz>,
#		Dan Meszaros <dmeszar@suse.cz>,
#		Jiri Suchomel <jsuchome@suse.cz>
#
module Yast
  module SoundWizardsInclude
    def initialize_sound_wizards(include_target)
      Yast.import "UI"

      textdomain "sound"

      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Sequencer"
      Yast.import "Wizard"
      Yast.import "Sound"

      Yast.include include_target, "sound/card_wizard.rb"
      Yast.include include_target, "sound/read_routines.rb"
      Yast.include include_target, "sound/routines.rb"
      Yast.include include_target, "sound/volume_routines.rb"
      Yast.include include_target, "sound/write_routines.rb"
      Yast.include include_target, "sound/volume.rb"
      Yast.include include_target, "sound/options.rb"
      Yast.include include_target, "sound/complex.rb"
      Yast.include include_target, "sound/manual.rb"


      @was_complex = false
    end

    # dialog for manual card selection
    # @return [Symbol] next dialog
    def _snd_manual
      res = sound_manual
      ui = Ops.get_symbol(res, "ui", :abort)

      if ui == :next
        Sound.save_entry = update_manual_card(res)
        Sound.card_id = -1
      end
      Sound.save_entry = {} if ui == :back
      ui
    end

    # sound card deletion
    # @return [Symbol] next dialog
    def _snd_delete
      if !Sound.use_ui ||
          # popup question
          Popup.YesNo(_("Do you really want to delete this entry?"))
        return :next if !stop_programs

        # we have to remember volume/mute settings because after a
        # card removal everything is muted and set to 0.
        vol_settings = get_vol_settings
        vol_settings = deep_copy(Sound.volume_settings) if Mode.config

        # remember info about removed card
        removed_card = Ops.get(Sound.modules_conf, Sound.card_id, {})
        removed_info = {}

        # get hwcfg file from list of configured cards
        Builtins.foreach(Sound.modules_conf) do |c|
          if Ops.get_string(c, "unique_key", "") ==
              Ops.get_string(removed_card, "unique_key", "unknown")
            Ops.set(removed_info, "hwcfg", Ops.get_string(c, "hwcfg", ""))
          end
        end 


        Sound.modules_conf = Builtins.remove(Sound.modules_conf, Sound.card_id)
        Sound.modules_conf = recalc_save_entries(Sound.modules_conf)

        Builtins.y2milestone("removed_card: %1", removed_card)

        if Ops.greater_than(Builtins.size(removed_card), 0)
          Ops.set(
            removed_info,
            "bus_hwcfg",
            Ops.get_string(removed_card, "bus_hwcfg", "")
          )
          Ops.set(
            removed_info,
            "sysfs_bus_id",
            Ops.get_string(removed_card, "sysfs_bus_id", "")
          )
          Ops.set(
            removed_info,
            "unique_key",
            Ops.get_string(removed_card, "unique_key", "")
          )
          Ops.set(
            removed_info,
            "module",
            Ops.get_string(removed_card, "module", "")
          )

          if !Builtins.contains(Sound.removed_info, removed_info)
            Sound.removed_info = Builtins.add(Sound.removed_info, removed_info)
            Builtins.y2milestone("added removed card info: %1", removed_info)
          end
        end

        if Ops.get(vol_settings, Sound.card_id) != nil
          vol_settings = Builtins.remove(vol_settings, Sound.card_id)
          # we have to move old entry in global list:
          if !Mode.config
            Sound.volume_settings = Builtins.add(
              vol_settings,
              Ops.get(Sound.volume_settings, Sound.card_id, [])
            )
          else
            Sound.volume_settings = Builtins.eval(vol_settings)
          end
        end

        if !Mode.config
          sound_stop
          sound_start_tmp(true)
          set_vol_settings(vol_settings)
          # now we have to update the unconfigured cards list
          Sound.UpdateUnconfiguredCards
        end
      end
      :next
    end

    # configure selected card
    # @return [Symbol] next dialog
    def _snd_config
      if Ops.greater_or_equal(Sound.card_id, 0)
        Sound.save_entry = Ops.get(Sound.unconfigured_cards, Sound.card_id, {})
      end
      res = OneCardWizard(
        Sound.save_entry,
        Builtins.size(Sound.modules_conf),
        15,
        false,
        Sound.modules_conf
      )

      ui = Ops.get_symbol(res, "ui", :back)
      if ui == :next
        # copy card_entry from unconfigured to configured list
        Sound.modules_conf = Builtins.add(
          Sound.modules_conf,
          Ops.get_map(res, "return", {})
        )
        if Ops.greater_or_equal(Sound.card_id, 0)
          # if this this card was autodetedted, remove
          # card we've just configured from unconfigured card list.
          Sound.unconfigured_cards = Builtins.remove(
            Sound.unconfigured_cards,
            Sound.card_id
          )
        end
        if Builtins.size(Sound.unconfigured_cards) == 0
          # no other detected && unconfigured cards remained
          return :detail
        end
      end
      ui
    end

    # complex dialog
    # @return [Symbol] next dialog
    def _snd_complex
      @was_complex = true
      res = sound_complex
      Ops.get_symbol(res, "ui")
    end


    # Main workflow of sound configuration (without read and write)
    # @return sequence result
    def MainSequence
      m_aliases = {
        "config"   => lambda { _snd_config },
        "manual"   => lambda { _snd_manual },
        "complex"  => lambda { _snd_complex },
        "delete"   => lambda { _snd_delete },
        "edit"     => [lambda { Edit() }, true],
        "editconf" => lambda { EditConfigured() },
        "mixer"    => lambda { Mixer() }
      }

      m_sequence = {
        "ws_start" => "complex",
        "config"   => {
          :next   => "complex",
          :detail => "complex",
          :abort  => :abort
        },
        "manual"   => { :next => "config", :abort => :abort },
        "complex"  => {
          :next   => :finish,
          :abort  => :abort,
          :add    => "manual",
          :edit   => "edit",
          :delete => "delete",
          :mixer  => "mixer"
        },
        "mixer"    => { :next => "complex", :abort => :abort },
        "edit"     => {
          :edit_new  => "config",
          :edit_conf => "editconf",
          :not_found => "complex"
        },
        "editconf" => { :next => "complex", :abort => :abort },
        "delete"   => { :next => "complex" }
      }

      Sequencer.Run(m_aliases, m_sequence)
    end

    # TODO create AutoSequence (used also for installation?)
    # - call of MainSequence with some work before and after

    # Whole configuration of sound
    # @return sequence result
    def SoundSequence
      Sound.use_ui = true

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("org.openSUSE.YaST.Sound")

      if !Mode.config && !Sound.installation
        return :abort if !Sound.Read(true)
        PulseAudio.Read
        Sound.StoreSettings
      end

      if Sound.installation
        Sound.StoreSettings
        if Sound.detected_cards == [] && Sound.modules_conf == []
          Sound.DetectOldCards
        end
        Sound.UpdateUnconfiguredCards
        sound_stop
        sound_start_tmp(true)
        # init mixer for all soundcards
        index = 0
        Builtins.maplist(Sound.modules_conf) do |card|
          Sound.InitMixer(index, Ops.get_string(card, "module", ""))
          index = Ops.add(index, 1)
        end
      end

      n_cards = 0
      all_cards_num = Builtins.size(Sound.unconfigured_cards)

      nm256_opl3sa2_warn(
        Builtins.flatten(
          Builtins.add([Sound.modules_conf], Sound.unconfigured_cards)
        )
      )

      if Builtins.size(
          Builtins.flatten(
            Builtins.add([Sound.modules_conf], Sound.unconfigured_cards)
          )
        ) == 1
        nm256out = nm256hack(
          Ops.get_string(Sound.unconfigured_cards, [0, "module"], "")
        )
        Builtins.y2debug("continue configuring: %1", nm256out)
        if !nm256out
          UI.CloseDialog
          return :back
        end
      end

      ui = MainSequence()

      if ui == :back || ui == :abort
        Sound.RestoreSettings if Sound.installation
        UI.CloseDialog
        return :back
      end

      n_cards = Builtins.size(Sound.modules_conf)

      save_map = {}

      if Sound.installation
        if ui != :finish
          Sound.RestoreSettings
        else
          ui = :next
        end # in installation mode, `finish is end of installation
      end

      if ui == :finish && !Mode.config
        if !Sound.installation &&
            (Sound.Changed || Sound.GetModified ||
              !Sound.AllRequiredPackagesInstalled)
          Sound.Write
        else
          Builtins.y2milestone("Not writing the configuration")
        end

        if PulseAudio.Modified
          Builtins.y2milestone("Writing changed PulseAudio configuration...")
          PulseAudio.Write
        end
      end

      UI.CloseDialog
      ui
    end
  end
end
