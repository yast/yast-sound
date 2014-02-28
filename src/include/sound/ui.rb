# encoding: utf-8

#
# File:
#   ui.ycp
#
# Module:
#   Sound
#
# Summary:
#   user interface functions for sound module
#
# Authors:
#   Dan Veselý <dan@suse.cz>
#   Dan Meszaros <dmeszar@suse.cz>
#
module Yast
  module SoundUiInclude
    def initialize_sound_ui(include_target)
      Yast.import "UI"
      textdomain "sound"
      Yast.import "Sound"
      Yast.import "Wizard"
      Yast.import "Popup"
      Yast.import "Label"
    end

    #  dialog to be displayed when user presses 'Abort' button
    #	@return [Boolean] yes/no
    def ReallyAbort
      config_changed = Sound.Changed
      Builtins.y2milestone(
        "Sound config changed: %1",
        config_changed
      )

      # no change, abort immediately
      return true if !config_changed

      Popup.ReallyAbort(config_changed)
    end

    # quick config dialog widget
    # @param [String] name card model
    # @param [String] cname alias for modules conf
    # @param [Fixnum] cpos position of the card
    # @return [Yast::Term] with widget
    def AutoconfDlg(name, cname, cpos)
      clab = ""
      if Ops.less_than(cpos, 3)
        clab = Ops.add(
          "\n",
          Builtins.sformat(
            Ops.get_string(Sound.STRINGS, ["soundCount", cpos], ""),
            cname
          )
        )
      else
        clab = Ops.add(
          "\n",
          Builtins.sformat(
            Ops.get_string(Sound.STRINGS, ["soundCount", 3], ""),
            cname,
            Ops.add(cpos, 1)
          )
        )
      end

      con = VBox(
        VSpacing(1),
        # this is the first part of message "The sound card 'cardname'
        # will be configured as the first snd card"
        Label(Opt(:hstretch), _("The sound card\n")),
        HBox(HSpacing(5), Label(Opt(:hstretch), name)),
        Label(Opt(:hstretch), clab),
        VSpacing(1),
        HBox(
          HSpacing(5),
          RadioButtonGroup(
            Id(:action),
            VBox(
              RadioButton(
                Id(:quick),
                Opt(:hstretch, :notify),
                # radio button label - type of setup
                _("&Quick automatic setup"),
                true
              ),
              VSpacing(0.3),
              RadioButton(
                Id(:normal),
                Opt(:hstretch, :notify),
                # radio button label - type of setup
                _("Normal &setup")
              ),
              VSpacing(0.3),
              RadioButton(
                Id(:options),
                Opt(:hstretch, :notify),
                # radio button label - type of setup
                _("Advanced setup with possibility to change &options")
              )
            )
          )
        ),
        VStretch()
      )
      deep_copy(con)
    end

    #  DisplayName
    #
    # @param [String] name card model
    # @param [String] cname sound card alias for modules conf
    # @param [Fixnum] cpos cards position
    # @param [Fixnum] flags enable/disable radiobuttons accordingly
    # @return [Hash] symbol of next dialog
    def DisplayName(name, cname, cpos, flags)
      helptext = Ops.get_string(Sound.STRINGS, "DisplayName", "")
      con = AutoconfDlg(name, cname, cpos)
      # dialog header
      Wizard.SetContents(
        _("Sound Card Configuration"),
        con,
        helptext,
        true,
        true
      )

      # dialog title
      flagc = 1
      flagp = 0
      selected = false
      flages = [:quick, :normal, :intro]

      while Ops.less_than(flagp, 3)
        if Ops.bitwise_and(flagc, flags) == 0
          UI.ChangeWidget(
            Id(Ops.get_symbol(flages, flagp, :quick)),
            :Enabled,
            false
          )
        else
          if !selected
            selected = true
            UI.ChangeWidget(
              Id(:action),
              :CurrentButton,
              Ops.get_symbol(flages, flagp, :quick)
            )
          end
        end
        flagp = Ops.add(flagp, 1)
        flagc = Ops.multiply(flagc, 2)
      end

      Wizard.RestoreNextButton

      input = :quick
      begin
        if input == :cancel || input == :abort
          return { "ui" => :abort } if ReallyAbort()
        end
        input = Convert.to_symbol(UI.UserInput)
      end while input != :next && input != :back

      output = input
      if input == :next
        output = Convert.to_symbol(UI.QueryWidget(Id(:action), :CurrentButton))
        output = :next if output == :normal
      end
      { "ui" => output }
    end
  end
end
