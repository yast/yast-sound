# encoding: utf-8

# File:	modules/Joystick.ycp
# Package:	Joustick configuration
# Summary:	Joystick data
# Authors:	Ladislav Slezak <lslezak@suse.cz>
require "yast"

module Yast
  class JoystickClass < Module
    def main
      textdomain "sound"

      Yast.import "Mode"
      Yast.import "Service"
      Yast.import "Directory"

      @joy_cmd = Ops.add(Directory.bindir, "/joystickdrivers")

      # joystick config datastructure (list of maps)
      @joystick = []

      @vars = [
        "GAMEPORT_MODULE",
        "JOYSTICK_MODULE",
        "JOYSTICK_MODULE_OPTION",
        "JOYSTICK_CONTROL",
        "JOYSTICK_CONTROL_PORT"
      ]

      @joystick_backup = []

      @start = ""

      @modified = false

      # comment for JOYSTICK_MODULE section in sysconfig
      @module_comment = ""

      @generic_joystick = "Generic Analog Joystick"
      # database entry
      @generic_joystick_translated = _("Generic Analog Joystick")

      @detected_joysticks = []
    end

    def Detected
      deep_copy(@detected_joysticks)
    end

    def Detect
      @detected_joysticks = Convert.convert(
        SCR.Read(path(".probe.joystick")),
        :from => "any",
        :to   => "list <map>"
      )

      nil
    end

    # Reverts the internal joystick configuration to the original state
    # read by Read() function
    def Revert
      Builtins.y2milestone(
        "Reverting the joystick config back to: %1",
        @joystick_backup
      )
      @joystick = deep_copy(@joystick_backup)

      nil
    end

    # Get list of all required joystick kernel modules
    # @return [Array] list of modules
    def RequiredKernelModules
      ret = []

      Builtins.foreach(
        Convert.convert(@joystick, :from => "list", :to => "list <map>")
      ) do |j|
        gport = Ops.get_string(j, "GAMEPORT_MODULE", "")
        jmod = Ops.get_string(j, "JOYSTICK_MODULE", "")
        ret = Builtins.add(ret, gport) if gport != nil && gport != ""
        ret = Builtins.add(ret, jmod) if jmod != nil && jmod != ""
      end 


      # remove duplicates
      ret = Builtins.toset(ret)

      Builtins.y2milestone("Required joystick modules: %1", ret)

      deep_copy(ret)
    end

    def format_model_line(model, attached_to)
      Builtins.sformat("# Model: %1, Attached to: %2\n", model, attached_to)
    end

    def parse_model_line(line)
      regexp = "^#[ \t]*Model: (.*),[ \t]*Attached to:[ \t]*(.*)$"

      model = Builtins.regexpsub(line, regexp, "\\1")
      attached_to = Builtins.regexpsub(line, regexp, "\\2")

      model = "" if model == nil
      attached_to = "" if attached_to == nil

      Builtins.y2milestone(
        "Parsed model line: %1 -> model: %2, attached_to: %3",
        line,
        model,
        attached_to
      )

      [model, attached_to]
    end

    # Read all joystick settings from the SCR
    # @param [Proc] abort A block that can be called by Read to find
    #	      out whether abort is requested. Returns true if abort
    #	      was pressed.
    # @return True on success
    def Read(abort)
      abort = deep_copy(abort)
      # values for test mode
      if Mode.test == true
        @joystick = [
          {
            "GAMEPORT_MODULE"        => "ns558",
            "JOYSTICK_CONTROL"       => "Joystick",
            "JOYSTICK_CONTROL_PORT"  => "",
            "JOYSTICK_MODULE"        => "analog",
            "JOYSTICK_MODULE_OPTION" => "",
            "model"                  => "Generic Analog Joystick"
          },
          {
            "GAMEPORT_MODULE"        => "",
            "JOYSTICK_CONTROL"       => "",
            "JOYSTICK_CONTROL_PORT"  => "",
            "JOYSTICK_MODULE"        => "",
            "JOYSTICK_MODULE_OPTION" => "",
            "model"                  => ""
          },
          {
            "GAMEPORT_MODULE"        => "",
            "JOYSTICK_CONTROL"       => "",
            "JOYSTICK_CONTROL_PORT"  => "",
            "JOYSTICK_MODULE"        => "",
            "JOYSTICK_MODULE_OPTION" => "",
            "model"                  => ""
          },
          {
            "GAMEPORT_MODULE"        => "",
            "JOYSTICK_CONTROL"       => "",
            "JOYSTICK_CONTROL_PORT"  => "",
            "JOYSTICK_MODULE"        => "",
            "JOYSTICK_MODULE_OPTION" => "",
            "model"                  => ""
          }
        ]
        @joystick_backup = deep_copy(@joystick)

        return true
      end

      pos = 0

      @joystick = []

      while Ops.less_than(pos, 4)
        j = {}

        # go thru 'vars' list and read all variable values
        Builtins.foreach(@vars) do |v|
          tmp = Convert.to_string(
            SCR.Read(
              Builtins.topath(
                Builtins.sformat(".sysconfig.joystick.%1_%2", v, pos)
              )
            )
          )
          j = Builtins.add(j, v, tmp) if tmp != nil
        end

        # read model comment
        model = Convert.to_string(
          SCR.Read(
            Builtins.topath(
              Builtins.sformat(
                ".sysconfig.joystick.JOYSTICK_MODULE_%1.comment",
                pos
              )
            )
          )
        )
        attached_to = ""

        Builtins.y2debug("Read model comment: %1", model)

        # remove trailing newline character
        if Ops.greater_than(Builtins.size(model), 0) &&
            Builtins.substring(model, Ops.subtract(Builtins.size(model), 1), 1) == "\n"
          model = Builtins.substring(
            model,
            0,
            Ops.subtract(Builtins.size(model), 1)
          )
        end

        # if comment has more lines get last line as model name
        lines = Builtins.splitstring(model, "\n")

        # select last line from comment
        if Ops.greater_than(Builtins.size(lines), 1)
          model = Ops.get(lines, Ops.subtract(Builtins.size(lines), 1), "")

          # store global comment for joystick modules -
          # - it is before first module
          if pos == 0
            lines = Builtins.remove(
              lines,
              Ops.subtract(Builtins.size(lines), 1)
            )
            @module_comment = Builtins.mergestring(lines, "\n")

            Builtins.y2debug("global comment: %1", @module_comment)
          end
        end

        # set model
        if SCR.Read(
            Builtins.topath(
              Builtins.sformat(".sysconfig.joystick.JOYSTICK_MODULE_%1", pos)
            )
          ) == "" ||
            model == nil
          model = ""
        else
          info = parse_model_line(model)

          model = Ops.get(info, 0, "")
          attached_to = Ops.get(info, 1, "")
        end

        Ops.set(j, "model", model)
        Ops.set(j, "attached_to", attached_to)

        @joystick = Builtins.add(@joystick, j)

        pos = Ops.add(pos, 1)
      end

      @joystick_backup = deep_copy(@joystick)

      Detect()
      true
    end

    # Return configuration status
    # @return true if configuration was changed
    def Changed
      @joystick != @joystick_backup
    end

    # Update the SCR of the one joystick
    # @param [Fixnum] pos joystick number
    def SaveOneJoystick(pos)
      # first remove old settings
      Builtins.foreach(@vars) do |v|
        SCR.Write(
          Builtins.topath(Builtins.sformat(".sysconfig.joystick.%1_%2", v, pos)),
          ""
        )
      end

      # delete old model
      SCR.Write(
        Builtins.topath(
          Builtins.sformat(
            ".sysconfig.joystick.JOYSTICK_MODULE_%1.comment",
            pos
          )
        ),
        ""
      )

      j = Ops.get_map(@joystick, pos, {})

      Builtins.foreach(@vars) do |v|
        SCR.Write(
          Builtins.topath(Builtins.sformat(".sysconfig.joystick.%1_%2", v, pos)),
          Ops.get_string(j, v, "")
        )
        if Ops.get_string(j, v, "") != ""
          # if there is variable with value != "" enable joystick service
          @start = "enable"
        end
      end

      # write model comment
      model = Ops.get_string(j, "model", "")
      attached_to = Ops.get_string(j, "attached_to", "")

      # add comment before first model
      if pos == 0
        if Ops.greater_than(Builtins.size(model), 0)
          model = Ops.add(
            Ops.add(@module_comment, "\n"),
            format_model_line(model, attached_to)
          )
        else
          model = Ops.add(@module_comment, "\n#\n")
        end
      else
        if Ops.greater_than(Builtins.size(model), 0)
          model = format_model_line(model, attached_to)
        end
      end

      Builtins.y2debug("Read model comment: %1", model)

      if Ops.greater_than(Builtins.size(model), 0)
        SCR.Write(
          Builtins.topath(
            Builtins.sformat(
              ".sysconfig.joystick.JOYSTICK_MODULE_%1.comment",
              pos
            )
          ),
          model
        )
      end
      true
    end

    # Stop joystick service
    def Stop
      cmd = Ops.add(@joy_cmd, " unload")
      Builtins.y2milestone("Executing: %1", cmd)
      SCR.Execute(path(".target.bash"), cmd) == 0
    end

    # Write sysconfig values (flush)
    def WriteConfig
      SCR.Write(path(".sysconfig.joystick"), nil)
    end

    # Start joystick service and insserv it
    def StartAndEnable
      if @start == "enable"
        cmd = Ops.add(@joy_cmd, " load")
        Builtins.y2milestone("Executing: %1", cmd)
        SCR.Execute(path(".target.bash"), cmd)
      end

      Service.Adjust("joystick", @start)
      true
    end

    # Update the SCR according to joystick settings
    # @param [Proc] abort A block that can be called by Write to find
    #	      out whether abort is requested. Returns true if abort
    #	      was pressed.
    # @return True on success
    def Write(abort)
      abort = deep_copy(abort)
      # do not write anything in the test mode and if nothing was changed
      return true if Mode.test == true || !@modified

      pos = 0

      @start = "disable"

      # stop joystick service
      Stop()

      while Ops.less_than(pos, 4)
        # update /etc/sysconfig/joystick file
        SaveOneJoystick(pos)
        pos = Ops.add(pos, 1)
      end

      # flush config to file
      WriteConfig()

      # start joystick service
      # enable/disable service
      StartAndEnable()

      Builtins.y2milestone("%1", "Joystick configuration was written.")

      true
    end

    # Get all joystick settings from the first parameter
    # (For use by autoinstallation.)
    # @param [Array] settings The YCP structure to be imported.
    # @return True on success
    def Import(settings)
      settings = deep_copy(settings)
      @joystick = deep_copy(settings)
      true
    end

    # Dump the joystick settings to a single map
    # (For use by autoinstallation.)
    # @return Dumped settings (later acceptable by Import ())
    def Export
      deep_copy(@joystick)
    end

    # Build a textual summary that can be used e.g. in inst_hw_config () or
    # something similar.
    # @return Summary of the configuration.
    def Summary
      _("Summary of the joystick configuration...")
    end

    publish :variable => :joystick, :type => "list"
    publish :variable => :start, :type => "string"
    publish :variable => :modified, :type => "boolean"
    publish :variable => :generic_joystick, :type => "string"
    publish :variable => :generic_joystick_translated, :type => "string"
    publish :function => :Detected, :type => "list <map> ()"
    publish :function => :Detect, :type => "void ()"
    publish :function => :Revert, :type => "void ()"
    publish :function => :RequiredKernelModules, :type => "list <string> ()"
    publish :function => :Read, :type => "boolean (block <boolean>)"
    publish :function => :Changed, :type => "boolean ()"
    publish :function => :SaveOneJoystick, :type => "boolean (integer)"
    publish :function => :Stop, :type => "boolean ()"
    publish :function => :WriteConfig, :type => "boolean ()"
    publish :function => :StartAndEnable, :type => "boolean ()"
    publish :function => :Write, :type => "boolean (block <boolean>)"
    publish :function => :Import, :type => "boolean (list)"
    publish :function => :Export, :type => "list ()"
    publish :function => :Summary, :type => "string ()"
  end

  Joystick = JoystickClass.new
  Joystick.main
end
