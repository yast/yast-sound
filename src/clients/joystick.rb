# encoding: utf-8

#
# File:
#   joystick.ycp
#
# Module:
#   Sound
#
# Authors:
#   Dan Meszaros <dmeszar@suse.cz>
#   Ladislav Slezak <lslezak@suse.cz>
#
# YaST2 joystick configuration client
#
module Yast
  class JoystickClient < Client
    def main
      Yast.import "UI"

      textdomain "sound"

      Yast.import "Joystick"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Progress"
      Yast.import "Sequencer"
      Yast.import "Sound"
      Yast.import "Wizard"
      Yast.import "CommandLine"

      Yast.include self, "sound/joy_dialog.rb"
      Yast.include self, "sound/write_routines.rb"

      # abort block for read/write dialogs
      @abort_block = lambda { false }



      @cmdline_description = {
        "id"         => "joystick",
        "guihandler" => fun_ref(method(:StartGUI), "symbol ()")
      }

      CommandLine.Run(@cmdline_description)
    end

    # Save to joystick option to the sound card module
    def save_sound_card_joy_config
      # save modules_conf now
      SaveModulesOptions(Sound.modules_conf)
      SCR.Write(path(".modprobe_sound"), nil)
    end

    # Display joystick configuration - the main dialog
    # @return [Symbol] Symbol of pressed button
    def joystick_configuration
      joystick_overview
    end

    # Save joystick configuration
    # @return [Symbol] Return `next (for wizard sequencer)
    def saveconfig
      Joystick.Write(@abort_block)
      # Save possible changed sound configuration
      # Only when joystick client is run stand alone! Otherwise it is saved
      # by sound module!
      save_sound_card_joy_config if Sound.Changed
      :next
    end

    # revert the joystick configuration back to the original state after pressing Abort
    def revert_config
      if Joystick.Changed
        Builtins.y2milestone("Reverting joystick configuration")
        Joystick.Revert

        saveconfig
      end

      # the Abort button has been pressed, just pass it further
      :abort
    end


    #*********************  MAIN  ***********************
    def StartGUI
      # sequence of dialogs
      sequence = {
        "ws_start" => "config",
        "config"   => { :next => "save", :abort => "revert" },
        "save"     => { :next => :ws_finish },
        "revert"   => { :abort => :abort }
      }

      # aliases for dialogs
      aliases = { "config" => lambda { joystick_configuration }, "save" => lambda(
      ) do
        saveconfig
      end, "revert" => lambda(
      ) do
        revert_config
      end }

      # create wizard dialog
      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("joystick")

      # read sound card configuration
      progress_orig = Progress.set(false)

      return :abort if !Sound.Read(false)

      Sound.StoreSettings

      Progress.set(progress_orig)

      # read joystick configuration
      Joystick.Read(@abort_block)

      Builtins.y2debug("Read joystick configuration: %1", Joystick.joystick)

      # start wizard sequencer
      Sequencer.Run(aliases, sequence)

      # close dialog
      Wizard.CloseDialog

      nil
    end
  end
end

Yast::JoystickClient.new.main
