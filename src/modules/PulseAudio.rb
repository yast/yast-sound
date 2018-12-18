# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2008 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File:	modules/PulseAudio.ycp
# Package:	PulseAudio configuration
# Summary:	Configuration of PulseAudio in desktop applications
# Authors:	Ladislav Slezák <lslezak@novell.com>
require "yast"

module Yast
  class PulseAudioClass < Module
    # path to the configuration script
    PA_SETUP_SCRIPT = "/usr/bin/setup-pulseaudio".freeze

    def main
      textdomain "sound"

      Yast.import "Mode"
      Yast.import "FileUtils"
      Yast.import "Summary"

      @pa_enabled = nil
      @modified = false

    end

    def Read
      # reset the modification flag
      @modified = false

      if FileUtils.Exists(PA_SETUP_SCRIPT)
        out = SCR.Execute(
          path(".target.bash_output"),
          "#{PA_SETUP_SCRIPT} --status"
        )
        Builtins.y2milestone("Read status: %1", out)

        @pa_enabled = Builtins.regexpmatch(
          Ops.get_string(out, "stdout", ""),
          "^enabled"
        )

        Builtins.y2milestone(
          "PulseAudio is %1",
          @pa_enabled ? "enabled" : "disabled"
        )
      else
        Builtins.y2warning(
          "PulseAudio setup script %1 is not present!",
          PA_SETUP_SCRIPT
        )
        return false
      end

      true
    end

    def Propose
      if @pa_enabled != nil
        Builtins.y2milestone("PA is configured, skipping proposal")
        return true
      end

      Builtins.y2milestone("Proposing PA status to enabled")

      @pa_enabled = true
      @modified = true

      Builtins.y2milestone("PulseAudio enabled: %1", @pa_enabled)
      true
    end

    def Write
      Builtins.y2milestone(
        "PulseAudio::Write(): pa_enabled: %1, modified: %2",
        @pa_enabled,
        @modified
      )

      if @pa_enabled != nil && @modified
        # always write the sysconfig to ensure that the setting
        # is written regardless whether setup-pulseaudio is installed or not

        # check whether PULSEAUDIO_ENABLE is already defined
        write_comment = SCR.Read(path(".sysconfig.sound.PULSEAUDIO_ENABLE")) == nil

        SCR.Write(
          path(".sysconfig.sound.PULSEAUDIO_ENABLE"),
          @pa_enabled ? "yes" : "no"
        )

        if write_comment
          # TODO: add a reload command?
          SCR.Write(
            path(".sysconfig.sound.PULSEAUDIO_ENABLE.comment"),
            "\n" +
              "## Path:\tHardware/Soundcard/PulseAudio\n" +
              "## Description:\tPulseAudio configuration\n" +
              "## Type:\tyesno\n" +
              "# Enable or disable PulseAudio system\n" +
              "#\n"
          )
        end

        # flush the changes
        SCR.Write(path(".sysconfig.sound"), nil)

        if FileUtils.Exists(PA_SETUP_SCRIPT)
          Builtins.y2milestone(
            "%1 PulseAudio support",
            @pa_enabled ? "Enabling" : "Disabling"
          )

          out = SCR.Execute(
            path(".target.bash_output"),
            "#{PA_SETUP_SCRIPT} #{@pa_enabled ? "--enable" : " --disable"}"
          )

          Builtins.y2milestone("Write status: %1", out)

          # reset the modification flag
          @modified = false
        else
          Builtins.y2warning(
            "PulseAudio setup script %1 is not present, cannot configure applications",
            PA_SETUP_SCRIPT
          )

          # reset the modification flag
          @modified = false

          return true
        end
      else
        Builtins.y2error(
          "PulseAudio is not configured, cannot save activate configuration"
        )
        return false
      end

      true
    end

    def Summary
      return "" if @pa_enabled == nil

      retlist = [
        Summary.Device(
          "PulseAudio",
          # part of a summary text (PulseAudio is disabled/enabled)
          @pa_enabled ? _("Enabled") : _("Disabled")
        )
      ]

      Summary.DevicesList(retlist)
    end

    def Reset
      Builtins.y2milestone("Resetting PulseAudio configuration")
      @pa_enabled = nil
      @modified = false

      nil
    end

    def Export
      return {} if @pa_enabled == nil

      { "pulse_audio_status" => @pa_enabled }
    end

    def Import(settings)
      settings = deep_copy(settings)
      if Builtins.haskey(settings, "pulse_audio_status")
        @pa_enabled = Ops.get_boolean(settings, "pulse_audio_status", false)
        @modified = true

        Builtins.y2milestone(
          "Imported PulseAudio configuration: pa_enabled: %1",
          @pa_enabled
        )
      else
        Builtins.y2milestone(
          "The imported configuration doesn't contain PulseAudio configuration."
        )
        @pa_enabled = nil
      end

      true
    end

    def Enable(enable)
      if enable == nil
        Builtins.y2error("PulseAudio::Enable(): nil argument")
      else
        @modified = enable != @pa_enabled
        @pa_enabled = enable
        Builtins.y2milestone("Enabling PulseAudio support: %1", @pa_enabled)

        Builtins.y2milestone("PulseAudio config has been changed") if @modified
      end

      nil
    end

    def Modified
      @modified
    end

    def Enabled
      @pa_enabled
    end

    publish :function => :Read, :type => "boolean ()"
    publish :function => :Propose, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Summary, :type => "string ()"
    publish :function => :Reset, :type => "void ()"
    publish :function => :Export, :type => "map ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Enable, :type => "void (boolean)"
    publish :function => :Modified, :type => "boolean ()"
    publish :function => :Enabled, :type => "boolean ()"
  end

  PulseAudio = PulseAudioClass.new
  PulseAudio.main
end
