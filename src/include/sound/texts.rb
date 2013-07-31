# encoding: utf-8

#
# File:
#   texts.ycp
#
# Module:
#   Sound
#
# Authors:
#   Dan Vesely <dan@suse.cz>
#   Dan Meszaros <dmeszar@suse.cz>
#
# Summary:
#   Text constants for sound module
#
module Yast
  module SoundTextsInclude
    def initialize_sound_texts(include_target)
      textdomain "sound"
      Yast.import "Sound"
    end

    #	Returns map with string values
    #  @return [Hash] with translated strings
    def STRINGS_
      ret = {
        "DisplayName" =>
          # help text - setup type selection 1/3
          _(
            "<p>\n" +
              "To configure this sound card and adjust its \n" +
              "volume, check <b>Normal setup</b>.\n" +
              "</p>\n"
          ) +
            # help text - setup type selection 2/3
            _(
              "<p>To set a special option, \n" +
                "check <b>Advanced setup</b>.\n" +
                "Most users will not need this.\n" +
                "</p>\n"
            ) +
            # help text - setup type selection 3/3
            _(
              "<p>\n" +
                "If you do not want to adjust volume or set options now, \n" +
                "check <b>Quick automatic setup</b>. You can set the volume and \n" +
                "change options later.\n" +
                "</p>\n"
            ),
        "quickConfig" =>
          # help text - quick configuration 1/3
          _(
            "<p>\n" +
              "To configure this sound card and adjust its \n" +
              "volume, check <b>Normal setup</b>.\n" +
              "</p>\n"
          ) +
            # help text - quick configuration 2/3
            _(
              "<p>\n" +
                "If you do not want to adjust the volume now, check <b>Quick \n" +
                "automatic setup</b>. You can set the volume and change options \n" +
                "later.\n" +
                "</p>\n"
            ) +
            # help text - quick configuration 3/3
            _(
              "<P>\n" +
                "To configure a card that was not detected, \n" +
                "check <B>More detailed installation of sound cards</B>.\n" +
                "</P>\n"
            ),
        "ManualDialog" =>
          # help text - sound card selection 1/2
          _(
            "<P>\n" +
              "<b>Manually</b> choose the sound card  to \n" +
              "configure. Search for a particular sound card by \n" +
              "entering the name in the search box.\n" +
              "</p>\n"
          ) +
            # help text - sound card selection 2/2
            _(
              "<p>\n" +
                "Select <b>All</b> to see the entire list of \n" +
                "supported sound card models.\n" +
                "</p>\n"
            ),
        "WhichDialog" =>
          # help text - which sound card to configure 1/2
          _(
            "<p>\n" +
              "Select the type of card to configure.\n" +
              "</p>\n"
          ) +
            # help text - which sound card to configure 2/2
            _(
              "<p>\n" +
                "If the list contains <b>autodetected</b> cards not yet \n" +
                "configured, select one and continue. Otherwise,\n" +
                "use <b>manual selection</b>.\n" +
                "</p>\n"
            ),
        "WhichDialogMsg" =>
          # To reset the sound configuration these programs must be terminated
          # (popup label message)
          _(
            "There are programs running that are currently using \n" +
              "the audio device.\n" +
              "To reset the configuration, these \n" +
              "programs must be terminated. Proceed?\n"
          ),
        "ComplexDialogMsg"  => _(
          "There are programs running that are currently using \n" +
            "the audio device.\n" +
            "To reset the configuration, these \n" +
            "programs must be terminated. Proceed?\n"
        ),
        "OptionsDialog" =>
          # help text - options dialog 1/2
          _(
            "<p>\n" +
              "Here, modify options for the sound modules. \n" +
              "If you are not <b>absolutely sure</b> what you are doing, \n" +
              "leave this dialog untouched. \n" +
              "</p>\n"
          ) +
            # help text - options dialog 2/2
            _(
              "<p>\n" +
                "Choose the option to set then use <b>Set</b> \n" +
                "to enable the new value. If there are known possible values for \n" +
                "the selected option, choose it under \n" +
                "<B>Possible value</B>. Reset all values \n" +
                "by pressing <b>Reset</b>. Numeric values can be entered as \n" +
                "decimal or hexadecimal (hexadecimal with a <b>0x</b> prefix).\n" +
                "</p>\n"
            ),
        "VolumeDialog" =>
          # help text - mixer setting 1/4
          _("<p>\nAdjust the volume.\n</p>\n") +
            # help text - mixer setting 2/4
            _(
              "<p>\n" +
                "Test your sound card by pressing <b>Test</b>.\n" +
                "\n" +
                "</p>\n"
            ) +
            # help text - mixer setting 3/4
            _(
              "<p>\n" +
                "After configuration is complete, use <b>amixer</b> \n" +
                "or any program of your choice to adjust the volume.\n" +
                "</p>\n"
            ) +
            # help text - mixer setting 4/4
            _(
              "<p><b>WARNING:</b> Start testing your\n" +
                "sound card with <b>very</b> low volume settings to prevent \n" +
                "damage.\n" +
                "</p>\n"
            ),
        "nm256hackWarning" =>
          # warning/question message
          _(
            "Configuring this sound card on some Sony VAIO notebooks \n" +
              "may fail if X is running. This can be avoided by setting the\n" +
              "snd_vaio_hack option value to 1 or by \n" +
              "configuring this card outside X. Proceed?\n"
          ),
        "SaveModuleEntry" =>
          # error message
          _("Error while saving '/etc/modules.conf'.\n"),
        "saveFinal1" =>
          # list of error
          _("These errors occurred during saving configuration:\n%1"),
        "saveFinal2" =>
          # information message - success
          _(
            "The sound card was successfully configured.\nIt is now available for use.\n"
          ),
        "saveFinal3"        => _("The sound configuration was saved."),
        "saveRCValues" =>
          # error message
          _("Error while saving file: %1 \n"),
        "SetAllChannels" =>
          # error message
          _("Error while setting volume.\n"),
        "ConfigSaveWarn"    => _(
          "The sound volume and configuration\n" +
            "for the sound card \n" +
            "will be saved now.\n"
        ),
        "ConfigSaveWarn2"   => _("The sound configuration will be saved now."),
        "soundCount"        => [
          # this is the second part of message "The sound card 'sbLive' will be configured as the first card"
          _("will be configured as the first sound card (%1)"),
          _("will be configured as the second sound card (%1)"),
          _("will be configured as the third sound card (%1)"),
          _("will be configured as the %2th sound card (%1)")
        ],
        "soundFontTitle" =>
          # do not translate "SoundFont" term (see http://en.wikipedia.org/wiki/Sound_font)
          _("Install SoundFonts"),
        "soundFontQuestion" =>
          # do not translate "SoundFont" term (see http://en.wikipedia.org/wiki/Sound_font)
          _(
            "Should YaST2 install the wavetable SoundFont-files from \nyour Soundblaster Live! or AWE driver CD?\n"
          ),
        "soundFontAppeal"   => _(
          "Insert the driver CD for the Soundblaster Live! or AWE card\nin the CD-ROM drive.\n"
        ),
        "soundFontFinal" =>
          # To translators: the message below will look like this: "14 SoundFont-files have been installed in /usr/share/..."
          # do not translate "SoundFont" term (see http://en.wikipedia.org/wiki/Sound_font)
          _("%1 SoundFont-files have been installed in %2."),
        "soundFontNotFound" =>
          # do not translate "SoundFont" term (see http://en.wikipedia.org/wiki/Sound_font)
          _("No SoundFont-files found."),
        "soundFontRetry"    => _("Would you like to change the CD and retry ?"),
        "opl3sa_nm256_warn" => _(
          "'%1' and '%2' sound cards were autodetected on your system. \n" +
            "For proper functionality, skip the '%1' sound card and \n" +
            "configure only the '%2'.\n"
        ),
        "selectHardware"    => _(
          "<P>\n" +
            "Hardware detection found a new sound card. To configure it, \n" +
            "select the appropriate item in list and press  \n" +
            "<B>Configure<B>.\n" +
            "</P>\n"
        ) +
          _(
            "<P>\n" +
              "Press <B>Change</B> to configure cards already installed.\n" +
              "</P>\n"
          ) +
          _(
            "<P>\n" +
              "To save the current configuration, press <B>Finish</B>.\n" +
              "</P>\n"
          )
      }

      # sound system dependent part:
      if Sound.use_alsa
        ret = Builtins.add(
          ret,
          "ComplexDialog",
          _("<p><big><b>Sound Cards</b><big></p>") +
            _(
              "<P>Select an unconfigured card from the list and press <B>Edit</B> to\n" +
                "configure it. If the card was not detected, press <B>Add</B> and\n" +
                "configure the card manually.</P>\n"
            ) +
            _(
              "<P>\n" +
                "To change the configuration of a card, select the card.\n" +
                "Then press <B>Edit</B>.\n" +
                "</P>\n"
            ) +
            _(
              "<p>\n" +
                "Use <b>Other</b> to set the volume of the selected card or configure\n" +
                "the module loaded for playing MIDI files (<b>Start Sequencer</b>).\n" +
                "Use <b>Play Test Sound</b> to test the selected card.\n" +
                "</p>\n"
            ) +
            _(
              "<P>PulseAudio daemon can be used to play sounds.\nUse <B>PulseAudio Configuration</B> to enable or disable it.</P>\n"
            ) +
            _(
              "<p>The sound device with index 0 is the default device used by system and applications.\nUse <b>Other</b> to set the selected sound device as the primary device.</p>"
            ) +
            _(
              "The applications which use OSS (Open Sound System) can use the software\n" +
                "mixer by using aoss wrapper. Use command <tt>aoss &lt;application&gt;</tt> to\n" +
                "start the application."
            )
        )

        ret = Builtins.add(
          ret,
          "ErrorDialog",
          _("<p>An error has occurred. </p>") +
            _(
              "<p>\n" +
                "If the the problem persists, try passing \n" +
                "<b>options</b> to the ALSA module. If your sound card still\n" +
                "will not work, try <i>OSS/Free</i> or \n" +
                "another module.\n" +
                "</p>\n"
            )
        )
      else
        ret = Builtins.add(
          ret,
          "ComplexDialog",
          _(
            "<p>\n" +
              "This is the complete sound card list. Use the <b>Finish</b> button \n" +
              "to save sound card information.\n" +
              "</p>\n"
          ) +
            _(
              "<p>\n" +
                "Use <b>Delete</b> to remove a configured sound card. \n" +
                "Use <b>Add sound card</b> to add a sound card.\n" +
                "</p>\n"
            )
        )
        ret = Builtins.add(
          ret,
          "ErrorDialog",
          _("<p>An error has occurred. </p>") +
            _("<p>You can try to pass some <b>options</b> to the module.</p>")
        )
      end
      deep_copy(ret)
    end
  end
end
