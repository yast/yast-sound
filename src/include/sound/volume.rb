# encoding: utf-8

# File:
#   volume.ycp
#
# Module:
#   Sound
#
# Summary:
#   Module where an attemp of inserting module is provided,
#   if everything goes well adjusting volume is done here
#   otherwise error message is displayed
#
# Authors:
#   Dan Vesely <dan@suse.cz>
#   Dan Meszaros <dmeszar@suse.cz>
#
# Steps:
#        1. try to insert kernel module
#        2. on succes unmute and volume dialog
#        3. on fail display error message
module Yast
  module SoundVolumeInclude
    def initialize_sound_volume(include_target)
      Yast.import "UI"

      textdomain "sound"
      Yast.import "Wizard"
      Yast.import "Popup"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Report"

      Yast.import "Sound"

      Yast.include include_target, "sound/volume_routines.rb" # PlayTest, setVolume
      Yast.include include_target, "sound/routines.rb" # FontsInstalled, HasFonts, InstallFonts
    end

    #	UI controls for volume setting dialog
    #
    #  @param [Hash] save_entry map with card info
    #  @param [Fixnum] vol initial volume (0-100)
    #  @return [Yast::Term] volume dialog contents
    def VolumeCon(save_entry, vol)
      save_entry = deep_copy(save_entry)
      slider = IntField(
        Id(:volume),
        Opt(:notify),
        # volume slider label
        _("&Volume"),
        0,
        100,
        vol
      )

      if UI.HasSpecialWidget(:Slider)
        slider = Slider(
          Id(:volume),
          Opt(:notify),
          # volume slider label
          _("&Volume"),
          0,
          100,
          vol
        )
      end

      con = HBox(
        HSpacing(3),
        VBox(
          VSpacing(),
          Top(
            VBox(
              # dialog title
              Left(Label(_("Settings for sound card"))),
              Label(Opt(:outputField), Ops.get_string(save_entry, "model", ""))
            )
          ),
          # frame label
          Frame(
            _("Volume Adjust and Test"),
            HBox(
              HSpacing(),
              VBox(
                VSpacing(0.5),
                slider,
                VSpacing(),
                # Test - button label
                PushButton(Id(:test), Opt(:key_F6), _("&Test")),
                VSpacing(0.5),
                # message label
                Label(_("Press 'Test' to start playing sound sample")),
                VSpacing(0.5)
              ),
              HSpacing()
            )
          ),
          VStretch()
        ),
        HSpacing(3)
      )
      deep_copy(con)
    end


    # This dialog simply reads user input and calls apropriate set funtion
    #
    # @param [Boolean] finish show 'finish' button instead of 'next'
    # @return [Symbol] next dialog
    def VolumeDialog(save_entry, finish, card_id)
      save_entry = deep_copy(save_entry)
      modname = Ops.get_string(save_entry, "module", "snd-dummy")
      master_elem = Ops.get_string(
        Sound.db_modules,
        [modname, "main_volume"],
        "Master"
      )

      help_text = Ops.get_string(Sound.STRINGS, "VolumeDialog", "")
      vol = 50

      channels = Ops.get(Sound.volume_settings, card_id, [])
      Builtins.foreach(channels) do |ch|
        if Ops.get_string(ch, 0, "") == master_elem
          vol = Ops.get_integer(ch, 1, 50)
        end
      end 


      con = VolumeCon(save_entry, vol)

      # dialog title
      Wizard.SetContents(_("Sound Card Volume"), con, help_text, true, true)

      UI.ChangeWidget(Id(:test), :Enabled, false) if Mode.config

      Wizard.SetNextButton(:next, Label.FinishButton) if finish

      if HasFonts(save_entry) && !FontsInstalled()
        # SoundFonts installation
        InstallFonts("", false)
      end

      setVolume(master_elem, card_id, vol)
      # some cards use Headphone instead of Master (bug #26539):
      setVolume("Headphone", card_id, vol)
      # some systems have only one speaker (#46555)
      setVolume("Master Mono", card_id, vol)
      # some systems use Front (#72971)
      setVolume("Front", card_id, vol)
      # some systems use iSpeaker (#251844)
      setVolume("iSpeaker", card_id, vol)
      # set also Speaker channel (bnc#330409)
      setVolume("Speaker", card_id, vol)

      ui = nil
      begin
        ui = Convert.to_symbol(UI.UserInput)

        if ui == :volume
          vol = Convert.to_integer(UI.QueryWidget(Id(:volume), :Value))
          setVolume(master_elem, card_id, vol)
          setVolume("Headphone", card_id, vol)
          setVolume("Master Mono", card_id, vol)
          setVolume("Front", card_id, vol)
          setVolume("iSpeaker", card_id, vol)
          setVolume("Speaker", card_id, vol)
        elsif ui == :test
          if !Mode.test
            msg = PlayTest(card_id)
            Popup.Message(msg) if msg != ""
          end
        elsif ui == :abort || ui == :cancel
          if ReallyAbort()
            ui = :abort
            break
          end
        end
      end while !Builtins.contains([:back, :next, :cancel], ui)
      ui
    end

    # shows error message in wizard
    # @param [Hash] save_entry card config
    # @param [String] err error string to be shown
    # @param [Boolean] finish show 'finish' button instead of 'next'
    # @return [Symbol] `back | `cancel
    def ErrorDialog(save_entry, err, finish)
      save_entry = deep_copy(save_entry)
      Builtins.y2debug("%1", save_entry)

      if !Sound.use_ui # used by cmd-line handlers
        Report.Error(err)
        return :back
      end
      help_text = Ops.get_string(Sound.STRINGS, "ErrorDialog", "")
      additional = ""

      if Ops.get_string(save_entry, "module", "") == "snd-cs461x"
        # error message
        additional = "\n\n" +
          _(
            "Please try to configure this sound card manually \n" +
              "using the \"Cirrus Logic CS4232\" or \"Cirrus \n" +
              "Logic CS4236\" driver and configure \n" +
              "its parameters using the 'Advanced setup'."
          )
      end

      con = HVCenter(
        VBox(
          # error message
          Label(_("An error occurred during the installation of")),
          VSpacing(),
          Label(Opt(:outputField), Ops.get_string(save_entry, "model", "")),
          VSpacing(),
          Label(Ops.add(err, additional))
        )
      )

      # dialog title
      Wizard.SetContents(Label.ErrorMsg, con, help_text, true, false)
      Wizard.SetNextButton(:next, Label.FinishButton) if finish

      UI.SetFocus(Id(:back))

      ui = nil
      begin
        ui = Convert.to_symbol(UI.UserInput)
        return :abort if ReallyAbort() if ui == :cancel || ui == :abort
      end until ui == :back || ui == :cancel

      ui
    end


    # shows volume dialog for normal setup or success dialog for quick setup
    # in case of failure show error dialog with 'next' button disabled
    # @param [Hash] save_entry card config
    # @param [Fixnum] card_id id of currently donfigured card
    # @param [Boolean] finish show 'finish' button instead of 'next'
    # @param [Boolean] quick quick/normal config
    # @param [Array] save_info config of previuosly configured cards
    # @return [Hash] result and next dialog
    def sound_volume(save_entry, card_id, finish, quick, save_info)
      save_entry = deep_copy(save_entry)
      save_info = deep_copy(save_info)
      Builtins.y2milestone(
        "sound_volume(%1, %2, %3, %4, %5) started",
        save_entry,
        card_id,
        finish,
        quick,
        save_info
      )

      Sound.LoadDatabase(true)

      need_restart = true
      err_msg = ""
      modules_conf_backup = deep_copy(Sound.modules_conf)

      stop_programs if Sound.use_ui

      # create new (temporary) modules.conf
      new_save = []
      if Ops.greater_or_equal(card_id, Builtins.size(save_info))
        new_save = Convert.convert(
          Builtins.add(save_info, save_entry),
          :from => "list",
          :to   => "list <map>"
        )
      else
        pos = -1
        new_save = Builtins.maplist(
          Convert.convert(save_info, :from => "list", :to => "list <map>")
        ) do |card|
          pos = Ops.add(pos, 1)
          pos == card_id ? deep_copy(save_entry) : deep_copy(card)
        end
      end

      Sound.modules_conf = deep_copy(new_save)

      # now restart sound system with new (current) card
      if !Mode.config && !Mode.autoinst
        sound_stop
        sound_start_tmp(true)

        err_msg = check_module(save_entry, card_id)

        attempt = 0
        while Ops.greater_than(Builtins.size(err_msg), 0) &&
            Ops.less_than(attempt, 5)
          Builtins.y2milestone("starting extra attempt: %1", attempt)

          # wait for a while and do the second test
          Builtins.sleep(1000)
          err_msg = check_module(save_entry, card_id)

          Builtins.y2milestone("result of the extra attempt: %1", err_msg)

          attempt = Ops.add(attempt, 1)
        end
      end

      ui = nil

      if Ops.greater_than(Builtins.size(err_msg), 0)
        ui = ErrorDialog(save_entry, err_msg, finish)
      else
        modname = Ops.get_string(save_entry, "module", "snd-dummy")

        Sound.InitMixer(card_id, modname) if !Mode.config && !Mode.autoinst
        if !quick
          ui = VolumeDialog(save_entry, finish, card_id)
        else
          master_elem = Ops.get_string(
            Sound.db_modules,
            [modname, "main_volume"],
            "Master"
          )

          setVolume(master_elem, card_id, Sound.default_volume)

          devs = Ops.get_map(Sound.db_modules, [modname, "mixer"], {})

          setVolume(
            "Headphone",
            card_id,
            Ops.get_integer(devs, "Headphone", Sound.default_volume)
          )
          setVolume(
            "Front",
            card_id,
            Ops.get_integer(devs, "Front", Sound.default_volume)
          )

          if Builtins.haskey(devs, "PCM")
            setVolume(
              "PCM",
              card_id,
              Ops.get_integer(devs, "PCM", Sound.default_volume)
            )
          end
          if Builtins.haskey(devs, "Master Mono")
            setVolume(
              "Master Mono",
              card_id,
              Ops.get_integer(devs, "Master Mono", Sound.default_volume)
            )
          end
          if Builtins.haskey(devs, "iSpeaker")
            setVolume(
              "iSpeaker",
              card_id,
              Ops.get_integer(devs, "iSpeaker", Sound.default_volume)
            )
          end
          if Builtins.haskey(devs, "Speaker")
            setVolume(
              "Speaker",
              card_id,
              Ops.get_integer(devs, "Speaker", Sound.default_volume)
            )
          end

          ui = :next
        end
        storeVolume(card_id) if !Mode.config && !Mode.autoinst
      end

      Sound.modules_conf = deep_copy(modules_conf_backup)

      if ui == :back || ui == :cancel || ui == :abort
        if !Mode.config && !Mode.autoinst
          sound_stop
          sound_start_tmp(true)
        end
      else
        # reset pointers to card table
        Sound.curr_driver = ""
        Sound.curr_vendor = ""
        Sound.curr_model = ""
      end

      if !Mode.config && !Mode.autoinst
        SCR.Execute(
          path(".target.bash"),
          "/usr/bin/killall aplay 2> /dev/null",
          {}
        )
      end
      Wizard.RestoreNextButton if Sound.use_ui

      { "ui" => ui, "return" => Builtins.size(err_msg) == 0 }
    end
  end
end
