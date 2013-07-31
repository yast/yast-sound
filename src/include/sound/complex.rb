# encoding: utf-8

# File:
#   sound_complex
#
# Module:
#   Sound
#
# Summary:
#   sound complex dialog
#
# Authors:
# Dan Vesely <dan@suse.cz>
# Dan Meszaros <dmeszar@suse.cz>
# Ladislav Slezak <lslezak@suse.cz>
#
# String corrections by Christian Steinruecken <cstein@suse.de>, 2001/08/01
#
#
module Yast
  module SoundComplexInclude
    def initialize_sound_complex(include_target)
      Yast.import "UI"

      textdomain "sound"

      Yast.import "Wizard"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Mode"
      Yast.import "WizardHW"
      Yast.import "Report"
      Yast.import "PulseAudio"

      Yast.import "Sound"
      Yast.include include_target, "sound/mixer.rb"
      Yast.include include_target, "sound/options.rb"
      Yast.include include_target, "sound/volume.rb"
      Yast.include include_target, "sound/volume_routines.rb" # PlayTest()

      @selected_card = ""
    end

    # creates summary table with card labels and thier states
    # (running/not running/dissappeared)
    # @return [Array] table contents
    def createHWTable
      Builtins.y2milestone("unconfigured_cards: %1", Sound.unconfigured_cards)
      Builtins.y2milestone("modules_conf: %1", Sound.modules_conf)

      ret = []

      if Sound.modules_conf != nil &&
          Ops.greater_than(Builtins.size(Sound.modules_conf), 0)
        Builtins.foreach(Sound.modules_conf) do |card|
          descr = []
          if Ops.get_string(card, ["options", "index"], "") != nil
            descr = Builtins.add(
              descr,
              Builtins.sformat(
                _("Configured as sound card number %1"),
                Ops.get_string(card, ["options", "index"], "")
              )
            )
          end
          if Ops.get(card, "module") != nil
            descr = Builtins.add(
              descr,
              Builtins.sformat(
                _("Driver %1"),
                Ops.get_string(card, "module", "")
              )
            )
          end
          pkgs = Sound.RequiredPackagesToInstallSummary(
            Ops.get_string(card, "module", "")
          )
          if Ops.greater_than(Builtins.size(pkgs), 0)
            descr = Builtins.add(descr, pkgs)
          end
          r = {
            "id"          => Ops.get_string(card, "unique_key", ""),
            "table_descr" => [
              Ops.get_string(card, ["options", "index"], ""),
              Ops.get_string(card, "model", "")
            ],
            "rich_descr"  => WizardHW.CreateRichTextDescription(
              Ops.get_string(card, "model", ""),
              descr
            )
          }
          ret = Builtins.add(ret, r)
        end
      end

      # sort the cards by index
      ret = Builtins.sort(ret) do |card1, card2|
        Ops.less_than(
          Builtins.tointeger(Ops.get_string(card1, ["table_descr", 0], "0")),
          Builtins.tointeger(Ops.get_string(card2, ["table_descr", 0], "0"))
        )
      end

      if Sound.unconfigured_cards != nil &&
          Ops.greater_than(Builtins.size(Sound.unconfigured_cards), 0)
        Builtins.foreach(Sound.unconfigured_cards) do |card|
          descr = []
          if Ops.get(card, "module") != nil
            descr = Builtins.add(
              descr,
              Builtins.sformat(
                _("Driver %1"),
                Ops.get_string(card, "module", "")
              )
            )
          end
          r = {
            "id"          => Ops.get_string(card, "unique_key", ""),
            "table_descr" => [
              _("Not configured"),
              Ops.get_string(card, "model", "")
            ],
            "rich_descr"  => WizardHW.CreateRichTextDescription(
              Ops.get_string(card, "model", ""),
              WizardHW.UnconfiguredDevice
            )
          }
          ret = Builtins.add(ret, r)
        end
      end

      Builtins.y2debug("table content: %1", ret)

      deep_copy(ret)
    end

    def getCardIndex(scards, uniq)
      scards = deep_copy(scards)
      ret = nil

      Builtins.foreach(scards) do |scard|
        if Ops.get(scard, "unique_key") == uniq
          if Ops.get(scard, ["options", "index"]) != nil
            ret = Builtins.tointeger(Ops.get(scard, ["options", "index"]))
          end
        end
      end if scards != nil

      Builtins.y2debug("found at index: %1", ret)

      ret
    end

    def getCardIndex2(scards, uniq)
      scards = deep_copy(scards)
      ret = nil

      if scards != nil
        i = 0
        Builtins.foreach(scards) do |scard|
          ret = i if Ops.get(scard, "unique_key") == uniq
          i = Ops.add(i, 1)
        end
      end

      Builtins.y2debug("found at index: %1", ret)

      ret
    end

    # function for enabling relevant controls in complex dialog
    # @param [Boolean] val boolean enable/disable

    def enableButtons(val)
      UI.ChangeWidget(Id(:b_delete), :Enabled, val)
      UI.ChangeWidget(Id(:b_options), :Enabled, val)
      UI.ChangeWidget(Id(:b_volume), :Enabled, val)

      nil
    end

    def SetItems
      # create description for WizardHW
      items = createHWTable
      Builtins.y2debug("items: %1", items)

      WizardHW.SetContents(items)

      nil
    end

    def Mixer
      ret = nil
      res = {}

      if Mode.config
        dialog_result = VolumeDialog(
          Ops.get(Sound.modules_conf, Sound.card_id, {}),
          true,
          Sound.card_id
        )

        Ops.set(res, "ui", dialog_result)
      else
        res = mixerDialog(Sound.card_id)
      end

      ret = Ops.get_symbol(res, "ui")

      ret = :abort if ret == :cancel

      ret
    end

    def EditConfigured
      ret = nil
      idx_conf = getCardIndex(
        Convert.convert(
          Sound.modules_conf,
          :from => "list <map>",
          :to   => "list <map <string, any>>"
        ),
        Sound.selected_uniq
      )
      idx_list = getCardIndex2(
        Convert.convert(
          Sound.modules_conf,
          :from => "list <map>",
          :to   => "list <map <string, any>>"
        ),
        Sound.selected_uniq
      )

      # the card is already configured
      if idx_conf != nil && idx_list != nil
        Builtins.y2milestone("Configuring card %1", Sound.selected_uniq)
        entry = Ops.get(Sound.modules_conf, idx_list, {})
        oldentry = deep_copy(entry)
        begin
          res = sound_options(entry)
          if Ops.get(res, "ui") == :next
            entry = Ops.get_map(res, "return", {})
            entry = add_common_options(entry, idx_conf)

            # update card data
            Sound.modules_conf = Builtins.maplist(Sound.modules_conf) do |card|
              if Ops.get_string(card, "unique_key", "") != Sound.selected_uniq
                next deep_copy(card)
              else
                next deep_copy(entry)
              end
            end

            Builtins.y2milestone("updated config: %1", Sound.modules_conf)

            if oldentry != entry
              # popup question text
              if Popup.YesNo(
                  _(
                    "To apply changes, the sound system\n" +
                      "must be restarted.\n" +
                      "Restart sound system now?\n"
                  )
                )
                Builtins.y2milestone("Restarting sound system...")
                sound_stop
                started = sound_start_tmp(true)
                Builtins.y2milestone("... restart done: %1", started)

                if !started
                  Report.Error(
                    _(
                      "Restart of the sound system has failed.\nCheck options of the driver.\n"
                    )
                  )
                  ret = :again
                  next
                end
              end
            end
            ret = :next
          elsif Ops.get(res, "ui") == :abort || Ops.get(res, "ui") == :cancel
            ret = :abort
          else
            ret = Ops.get_symbol(res, "ui")
          end
        end while ret == :again
      end

      ret
    end

    def Edit
      ret = nil
      idx_conf = getCardIndex2(
        Convert.convert(
          Sound.modules_conf,
          :from => "list <map>",
          :to   => "list <map <string, any>>"
        ),
        Sound.selected_uniq
      )
      idx_det = getCardIndex2(
        Convert.convert(
          Sound.unconfigured_cards,
          :from => "list <map>",
          :to   => "list <map <string, any>>"
        ),
        Sound.selected_uniq
      )

      Builtins.y2milestone(
        "uniq (%1) in configured: %2, in detected: %3",
        Sound.selected_uniq,
        idx_conf,
        idx_det
      )

      # the card is already configured
      if idx_conf != nil
        Builtins.y2milestone("reconfiguring card %1", Sound.selected_uniq)
        Sound.card_id = idx_conf
        ret = :edit_conf
      elsif idx_det != nil
        Builtins.y2milestone("adding new card %1", Sound.selected_uniq)
        Sound.card_id = idx_det
        ret = :edit_new
      else
        Builtins.y2error("card %1 was not found!", Sound.selected_uniq)
        ret = :not_found
      end

      ret
    end

    def PulseAudioPopup
      if !Mode.config && PulseAudio.Enabled == nil
        Builtins.y2error(
          "PulseAudio status is nil - the setup script is missing?"
        )
        # error popup message
        Popup.Error(_("PulseAudio is not installed or cannot be configured."))
        return
      end

      dlg = HBox(
        HSpacing(1),
        VBox(
          VSpacing(0.5),
          # frame label
          Frame(
            _("PulseAudio Configuration"),
            VBox(
              VSpacing(0.5),
              Left(
                CheckBox(
                  Id(:pulseaudio),
                  # check box label
                  _("&Enable PulseAudio Support"),
                  PulseAudio.Enabled == true
                )
              ),
              VSpacing(0.5)
            )
          ),
          VSpacing(Opt(:vstretch), 1),
          ButtonBox(
            PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
            PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
          ),
          VSpacing(0.5)
        ),
        HSpacing(1)
      )

      UI.OpenDialog(Opt(:decorated), dlg)

      ui = Convert.to_symbol(UI.UserInput)

      if ui == :ok
        # get the current value
        value = Convert.to_boolean(UI.QueryWidget(Id(:pulseaudio), :Value))

        # set the value
        PulseAudio.Enable(value)
      end

      UI.CloseDialog

      nil
    end

    def SequencerPopup
      dlg = HBox(
        HSpacing(1),
        VBox(
          VSpacing(0.5),
          # frame label
          Frame(
            _("Advanced Options"),
            VBox(
              VSpacing(0.5),
              Left(
                CheckBox(
                  Id(:sequencer),
                  # check box label
                  _("&Start Sequencer (Load MIDI Drivers)"),
                  Ops.get_string(Sound.rc_vars, "LOAD_ALSA_SEQ", "no") == "yes"
                )
              ),
              VSpacing(0.5)
            )
          ),
          VSpacing(Opt(:vstretch), 1),
          ButtonBox(
            PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
            PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
          ),
          VSpacing(0.5)
        ),
        HSpacing(1)
      )

      UI.OpenDialog(Opt(:decorated), dlg)

      ui = Convert.to_symbol(UI.UserInput)

      if ui == :ok
        # get current value
        value = Convert.to_boolean(UI.QueryWidget(Id(:sequencer), :Value)) ? "yes" : "no"

        # set the value
        Sound.rc_vars = Builtins.add(Sound.rc_vars, "LOAD_ALSA_SEQ", value)
      end

      UI.CloseDialog

      nil
    end

    # Configure the selected sound card as the primary (default) card.
    # @param [Fixnum] card_index index of the selected card in the internal structure
    # @param [Fixnum] alsa_index index of the selected card in ALSA
    def SetPrimaryCard(card_index, alsa_index)
      Builtins.y2milestone(
        "Setting card %1 (snd-card-%2) as the primary card",
        card_index,
        alsa_index
      )
      Builtins.y2debug("Before configuration: %1", Sound.modules_conf)

      index = 0
      Sound.modules_conf = Builtins.maplist(Sound.modules_conf) do |sound_card|
        # the new primary sound_card
        if index == card_index
          Ops.set(sound_card, ["options", "index"], "0")
          Ops.set(sound_card, "alias", "snd-card-0")
          Builtins.y2milestone("New primary card: %1", sound_card)
        # the old primary sound_card
        elsif Ops.get_string(sound_card, ["options", "index"], "") == "0"
          Ops.set(
            sound_card,
            ["options", "index"],
            Builtins.tostring(alsa_index)
          )
          Ops.set(
            sound_card,
            "alias",
            Builtins.sformat("snd-card-%1", alsa_index)
          )
          Builtins.y2milestone("Previous primary card: %1", sound_card)
        end
        index = Ops.add(index, 1)
        deep_copy(sound_card)
      end

      Builtins.y2debug("After configuration: %1", Sound.modules_conf)

      nil
    end

    # A dialog showing the detected cards and allowing to configure them.
    # @return [Object] The value of the resulting UserInput.
    def HardwareDialog
      show_fonts = false
      Builtins.maplist(Sound.modules_conf) do |card|
        show_fonts = true if HasFonts(card)
      end

      extra_buttons = [
        # menu item
        [:mixer, _("&Volume...")],
        # menu item
        [:play_test, _("Play &Test Sound")],
        # menu item
        [:seq, _("&Start Sequencer")],
        # menu item
        [:primary, _("Set as the &Primary Card")],
        # menu item
        [:pulseaudio, _("PulseAudio &Configuration...")]
      ]

      if show_fonts
        # menu item, do not translate "SoundFont" term (see http://en.wikipedia.org/wiki/Sound_font)
        extra_buttons = Builtins.add(
          extra_buttons,
          [:fonts, _("&Install SoundFonts...")]
        )
      end

      # dialog title
      WizardHW.CreateHWDialog(
        _("Sound Configuration"),
        Ops.get_string(Sound.STRINGS, "ComplexDialog", ""),
        # table header
        [_("Index"), _("Card Model")],
        extra_buttons
      )

      Wizard.SetNextButton(:next, Label.OKButton)
      Wizard.SetAbortButton(:abort, Label.CancelButton)
      Wizard.HideBackButton if !Mode.installation

      ret = :_dummy
      begin
        SetItems()

        # initialize selected_card
        @selected_card = WizardHW.SelectedItem if @selected_card == ""

        # set previously selected card
        WizardHW.SetSelectedItem(@selected_card)

        ev = WizardHW.WaitForEvent
        Builtins.y2milestone("WaitForEvent: %1", ev)

        ui = Ops.get_symbol(ev, ["event", "ID"])

        # remember the selected card
        @selected_card = Ops.get_string(ev, "selected", "")

        if ui == :add
          ret = :add
        elsif ui == :cancel || ui == :abort
          if ReallyAbort()
            ret = :abort
            break
          else
            ui = :skip_event
          end
        elsif ui == :delete
          uniq = WizardHW.SelectedItem
          idx = getCardIndex2(
            Convert.convert(
              Sound.modules_conf,
              :from => "list <map>",
              :to   => "list <map <string, any>>"
            ),
            uniq
          )
          Builtins.y2milestone("Sound card index: %1", idx)

          if idx != nil
            Sound.card_id = idx
            ret = :delete
          end
        elsif ui == :edit
          Sound.selected_uniq = WizardHW.SelectedItem
          ret = :edit
        elsif ui == :mixer
          uniq = WizardHW.SelectedItem
          idx = getCardIndex(
            Convert.convert(
              Sound.modules_conf,
              :from => "list <map>",
              :to   => "list <map <string, any>>"
            ),
            uniq
          )

          if idx != nil
            Sound.card_id = idx
            ret = :mixer
          end
        elsif ui == :fonts
          InstallFonts("", true)
        elsif ui == :seq
          SequencerPopup()
        # configure the current card as primary
        elsif ui == :primary
          uniq = WizardHW.SelectedItem
          # sound card index
          idx = getCardIndex2(
            Convert.convert(
              Sound.modules_conf,
              :from => "list <map>",
              :to   => "list <map <string, any>>"
            ),
            uniq
          )
          # alsa index (snd-card-X)
          idx2 = getCardIndex(
            Convert.convert(
              Sound.modules_conf,
              :from => "list <map>",
              :to   => "list <map <string, any>>"
            ),
            uniq
          )

          if idx != nil && idx2 != 0
            # set the primary card
            SetPrimaryCard(idx, idx2)
          end
        elsif ui == :pulseaudio
          PulseAudioPopup()
        elsif ui == :play_test
          uniq = WizardHW.SelectedItem
          # alsa index (snd-card-X)
          card_id = getCardIndex(
            Convert.convert(
              Sound.modules_conf,
              :from => "list <map>",
              :to   => "list <map <string, any>>"
            ),
            uniq
          )

          if card_id != nil && Ops.greater_or_equal(card_id, 0)
            Builtins.y2milestone("Playing test: card: %1", card_id)
            msg = PlayTest(card_id)

            Popup.Message(msg) if msg != ""
          else
            Builtins.y2warning("Invalid index '%1' for card: %2", card_id, uniq)
          end
        else
          ret = ui
        end
      end while !Builtins.contains(
        [:back, :abort, :next, :add, :edit, :delete, :mixer],
        ret
      )

      Wizard.RestoreNextButton
      Wizard.RestoreBackButton if !Mode.installation

      { "ui" => ret }
    end



    # ===== MAIN =====

    # just calls ComplexDialog
    # @return [Hash] passed from ComplexDialog
    def sound_complex
      to_delete = []
      config_mode = false

      HardwareDialog() 
      #    return ComplexDialog ();
    end
  end
end
