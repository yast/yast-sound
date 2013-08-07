# encoding: utf-8

#
#
# File:
#   sound.ycp
#
# Module:
#   Sound
#
# Authors:
#   Dan Vesely <dan@suse.cz>
#   Dan Meszaros <dmeszar@suse.cz>
#   Jiri Suchomel <jsuchome@suse.cz>
#
# Installation of the sound card. If the sound card was not auto-detected ask user.
#
#
module Yast
  class SoundClient < Client
    def main
      Yast.import "UI"
      textdomain "sound"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Sound module started")

      Yast.import "Mode"
      Yast.import "Directory"
      Yast.import "Popup"
      Yast.import "Sound"
      Yast.import "Joystick"
      Yast.import "Report"
      Yast.import "CommandLine"
      Yast.import "RichText"
      Yast.import "PulseAudio"

      Yast.include self, "sound/wizards.rb"

      @arg_n = Ops.subtract(Builtins.size(WFM.Args), 1)
      while Ops.greater_or_equal(@arg_n, 0)
        Mode.SetTest("test") if WFM.Args(@arg_n) == path(".test")
        @arg_n = Ops.subtract(@arg_n, 1)
      end

      # check for database existence
      if Sound.use_alsa && !File.exist?(Directory.datadir + "/sndcards.yml")
        # popup error message
        Report.Error(
          _("Sound card database not found. Please check your installation.")
        )
        return nil
      end


      # the command line description map
      @cmdline = {
        "id"         => "sound",
        # translators: command line help text for Sound module
        "help"       => _(
          "Sound card configuration module."
        ),
        "guihandler" => fun_ref(method(:SoundSequence), "symbol ()"),
        "initialize" => fun_ref(method(:SoundRead), "boolean ()"),
        "finish"     => fun_ref(method(:SoundWrite), "boolean ()"),
        "actions"    => {
          "summary"  => {
            "handler" => fun_ref(method(:SoundSummaryHandler), "boolean (map)"),
            # translators: command line help text for summary action
            "help"    => _(
              "Configuration summary of sound cards"
            )
          },
          "add"      => {
            "handler"         => fun_ref(
              method(:AddCardHandler),
              "boolean (map)"
            ),
            # translators: command line help text for add action
            "help"            => _(
              "Add sound card. Without parameters, add first one detected."
            ),
            "options"         => ["non_strict"],
            # help text for unknownd parameters
            "non_strict_help" => _(
              "Value of the specific module parameter."
            )
          },
          "remove"   => {
            "handler" => fun_ref(method(:RemoveCardHandler), "boolean (map)"),
            # translators: command line help text for remove action
            "help"    => _(
              "Remove sound cards"
            )
          },
          "playtest" => {
            "handler" => fun_ref(method(:TestCardHandler), "boolean (map)"),
            # translators: command line help text for test action
            "help"    => _(
              "Play test sound on given sound card"
            )
          },
          "show"     => {
            "handler" => fun_ref(method(:ShowCardHandler), "boolean (map)"),
            # translators: command line help text for test action
            "help"    => _(
              "Show the information of given sound card"
            )
          },
          "set"      => {
            "handler"         => fun_ref(
              method(:SetParametersHandler),
              "boolean (map)"
            ),
            # translators: command line help text for set action
            "help"            => _(
              "Set the new values for given card parameters."
            ),
            "options"         => ["non_strict"],
            # - for unknown parameter names
            # help text for unknownd parameters; do not translate 'show'
            "non_strict_help" => _(
              "Value of the specific module parameter. Use the 'show' command to see a list of allowed parameters."
            )
          },
          "volume"   => {
            "handler"         => fun_ref(
              method(:SetVolumeHandler),
              "boolean (map)"
            ),
            # translators: command line help text for volume action
            "help"            => _(
              "Set the volume of specific channels of the given card."
            ),
            "options"         => ["non_strict"],
            # - for unknown parameter names
            # help text;  do not translate 'channels' as command name
            "non_strict_help" => _(
              "Value of the specific channel (0-100). Use the 'channels' command to see a list of available channels."
            )
          },
          "modules"  => {
            "handler" => fun_ref(method(:ListModulesHandler), "boolean (map)"),
            # translators: command line help text for modules action
            "help"    => _(
              "List all available sound kernel modules."
            )
          },
          "channels" => {
            "handler" => fun_ref(method(:ListChannelsHandler), "boolean (map)"),
            # translators: command line help text for channels action
            "help"    => _(
              "List available volume channels of given card."
            )
          }
        },
        "options"    => {
          "card"   => {
            # translators: command line help text for the 'card' option
            "help" => _(
              "Number of sound card"
            ),
            "type" => "string"
          },
          "all"    => {
            # translators: command line help text for the 'all' option
            "help" => _(
              "All available sound cards"
            )
          },
          "module" => {
            # translators: command line help text for the 'module' option
            "help" => _(
              "Kernel module (driver) for the sound card"
            ),
            "type" => "string"
          },
          "play"   => {
            # translators: command line help text for the 'play' option
            "help" => _(
              "Play the test sound when the card is configured"
            )
          },
          "volume" => {
            # translators: command line help text for the 'volume' option
            "help" => _(
              "Volume value for the sound card (0-100)"
            ),
            "type" => "string"
          }
        },
        "mappings"   => {
          "summary"  => [],
          "add"      => ["card", "all", "module", "play", "volume"],
          "remove"   => ["card", "all"],
          #delete alias
          "playtest" => ["card"],
          "show"     => ["card"],
          "set"      => ["card", "volume"],
          #edit alias
          "channels" => ["card"],
          "volume"   => ["card", "play"],
          "modules"  => []
        }
      }

      # --------------------------------- cmd-line handlers
      # --------------------------------------------------------------------------


      @ret = nil

      if Sound.use_alsa
        @ret = CommandLine.Run(@cmdline)
      else
        @ret = SoundSequence()
      end

      Builtins.y2debug("ret == %1", @ret)

      Builtins.y2milestone("Sound module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)
    end

    # --------------------------------------------------------------------------
    # --------------------------------- cmd-line handlers

    # Print summary of basic options
    # @return [Boolean] false
    def SoundSummaryHandler(options)
      options = deep_copy(options)
      CommandLine.Print(RichText.Rich2Plain(Sound.Summary))
      false # do not call Write...
    end

    # Wrapper function for reading the settings (used by cmd-line)
    # @return [Boolean] success
    def SoundRead
      Sound.use_ui = false
      abort_block = lambda { false }
      ret = Sound.Read(false) && Joystick.Read(abort_block)
      # PulseAudio is optional, it may fail
      PulseAudio.Read
      ret
    end

    # Wrapper function for writing the settings (used by cmd-line)
    # @return [Boolean] success
    def SoundWrite
      Sound.Write
    end

    # Handler for adding new card
    # @param [Hash] options parameters on command line
    # @return [Boolean] success
    def AddCardHandler(options)
      options = deep_copy(options)
      card_no = Builtins.tointeger(Ops.get_string(options, "card", "-1"))
      all = Builtins.haskey(options, "all")
      modname = Ops.get_string(options, "module", "")
      ret = false

      if all || Sound.unconfigured_cards != [] && card_no == -1 && modname == ""
        card_no = 0
      end
      Sound.card_id = card_no # now Sound::card_id is index to Sound::unconfigured_cards

      # 1. choose the card to add
      save_entry = {}
      if Ops.greater_or_equal(Sound.card_id, 0) # -1 is for manual...
        save_entry = Ops.get(Sound.unconfigured_cards, Sound.card_id, {})
        if save_entry == {}
          # error message
          Report.Error("There is no such detected card.")
          return false
        end
      end
      if save_entry == {} # manual adding
        if modname == ""
          # error message (inssuficient parameters)
          Report.Error(
            "You must specify the kernel module name if you want to add a card which was not detected."
          )
          return false
        end
        save_entry = update_manual_card({ "module" => modname })
      end

      volume_b = Sound.default_volume
      if Builtins.haskey(options, "volume")
        Sound.default_volume = Builtins.tointeger(
          Ops.get_string(options, "volume", "75")
        )
      end
      begin
        save_info = deep_copy(Sound.modules_conf)
        Sound.card_id = Builtins.size(Sound.modules_conf) # id of new card

        save_entry = add_common_options(save_entry, Sound.card_id)
        save_entry = add_alias(save_entry, Sound.card_id)

        # now set the value of given kernel parameters...
        modname = Ops.get_string(save_entry, "module", "")
        params = get_module_params(modname)
        params = restore_mod_params(
          params,
          Ops.get_map(save_entry, "options", {})
        )
        Builtins.foreach(
          Convert.convert(params, :from => "map", :to => "map <string, map>")
        ) do |optname, o|
          if Builtins.haskey(options, optname) &&
              Ops.get_string(o, "value", "") !=
                Ops.get_string(options, optname, "")
            possible_values = string2vallist(Ops.get_string(o, "allows", ""))
            err = check_value(
              Ops.get_string(options, optname, ""),
              "string",
              possible_values
            )
            if err != ""
              CommandLine.Print(err)
              next
            end
            Ops.set(
              save_entry,
              ["options", optname],
              Ops.get_string(options, optname, "")
            )
          end
        end

        res = sound_volume(save_entry, Sound.card_id, true, true, save_info)
        ret = Ops.get_symbol(res, "ui", :back) == :next

        if ret
          Sound.modules_conf = Builtins.add(Sound.modules_conf, save_entry)
          if Ops.greater_or_equal(card_no, 0) # was autodetected
            Sound.unconfigured_cards = Builtins.remove(
              Sound.unconfigured_cards,
              card_no
            )
          end
          # result message, %1 is card name
          CommandLine.Print(
            Builtins.sformat(
              _("Successfully added card '%1'."),
              Ops.get_string(save_entry, "model", "")
            )
          )
          PlayTest(Sound.card_id) if Builtins.haskey(options, "play")
        end
        save_entry = Ops.get(Sound.unconfigured_cards, 0, {})
      end while all && ret && save_entry != {}

      Sound.default_volume = volume_b
      ret
    end

    # Handler for removing the sound card
    # @param [Hash] options parameters on command line
    # @return [Boolean] success
    def RemoveCardHandler(options)
      options = deep_copy(options)
      card_no = Builtins.tointeger(Ops.get_string(options, "card", "-1"))
      all = Builtins.haskey(options, "all")
      ret = false

      if card_no == -1 && Builtins.size(Sound.modules_conf) == 1 || all
        card_no = 0
      end # choose first card only if it is the only one
      if card_no == -1
        #error message
        Report.Error(_("You must specify the card number."))
        return false
      end
      if Ops.get(Sound.modules_conf, card_no) == nil
        #error message
        Report.Error(_("There is no such sound card."))
        return false
      end

      Sound.card_id = card_no
      begin
        ret = _snd_delete == :next
      end while all && ret && Ops.get(Sound.modules_conf, Sound.card_id) != nil

      ret
    end

    # Handler for playing the test sound
    # @param [Hash] options parameters on command line
    # @return [Boolean] false (no write)
    def TestCardHandler(options)
      options = deep_copy(options)
      card_no = Builtins.tointeger(Ops.get_string(options, "card", "-1"))
      if card_no == -1 && Ops.greater_than(Builtins.size(Sound.modules_conf), 0)
        card_no = 0
      end # choose first card if number is not given
      if Ops.get(Sound.modules_conf, card_no) == nil
        #error message
        Report.Error(_("There is no such sound card."))
        return false
      end
      ret = PlayTest(card_no)
      if ret != ""
        Report.Error(ret)
        return false
      end
      false # write not necessary
    end

    # Handler for showing sound card information
    # @param [Hash] options parameters on command line
    # @return [Boolean] false (no write)
    def ShowCardHandler(options)
      options = deep_copy(options)
      card_no = Builtins.tointeger(Ops.get_string(options, "card", "-1"))
      if card_no == -1 && Ops.greater_than(Builtins.size(Sound.modules_conf), 0)
        card_no = 0
      end # choose first card if number is not given
      save_entry = Ops.get(Sound.modules_conf, card_no)
      if save_entry == nil
        #error message
        Report.Error(_("There is no such sound card."))
        return false
      end
      modname = Ops.get_string(save_entry, "module", "")
      params = get_module_params(modname)
      params = restore_mod_params(
        params,
        Ops.get_map(save_entry, "options", {})
      )

      # label: list of card parameters will follow; %1 is card name, %2 driver
      out = Builtins.sformat(
        _("Parameters of card '%1' (using module %2):\n"),
        Ops.get_string(save_entry, "model", ""),
        modname
      )

      Builtins.foreach(
        Convert.convert(params, :from => "map", :to => "map <string, map>")
      ) do |optname, option|
        out = Ops.add(
          Ops.add(Ops.add(out, Builtins.sformat("\n%1", optname)), "\n\t"),
          getDescr(Ops.get(option, "descr"))
        )
        if Ops.get_string(option, "default", "") != ""
          # label (default value of sound module parameter)
          out = Ops.add(
            out,
            Builtins.sformat(
              _("\n\tDefault Value: %1"),
              Ops.get_string(option, "default", "")
            )
          )
        end
        if Ops.get_string(option, "value", "") != ""
          # label (current value of sound module parameter)
          out = Ops.add(
            out,
            Builtins.sformat(
              _("\n\tCurrent Value: %1"),
              Ops.get_string(option, "value", "")
            )
          )
        end
      end
      CommandLine.Print(out)

      false # write not necessary
    end

    # Handler for setting the paramerer values of sound card
    # @param [Hash] options parameters on command line
    # @return [Boolean] success
    def SetParametersHandler(options)
      options = deep_copy(options)
      card_no = Builtins.tointeger(Ops.get_string(options, "card", "-1"))
      card_no = 0 if card_no == -1 && Builtins.size(Sound.modules_conf) == 1 # choose first card only if it is the only one
      if card_no == -1
        #error message
        Report.Error(_("You must specify the card number."))
        return false
      end
      save_entry = Ops.get(Sound.modules_conf, card_no)
      if save_entry == nil
        #error message
        Report.Error(_("There is no such sound card."))
        return false
      end

      modname = Ops.get_string(save_entry, "module", "")
      params = get_module_params(modname)
      params = restore_mod_params(
        params,
        Ops.get_map(save_entry, "options", {})
      )
      options = Builtins.remove(options, "card")

      modified = false

      if Builtins.haskey(options, "volume")
        volume = Builtins.tointeger(Ops.get_string(options, "volume", "75"))
        master = Ops.get_string(
          Sound.db_modules,
          [modname, "main_volume"],
          "Master"
        )
        setVolume(master, card_no, volume)
        setVolume("Headphone", card_no, volume)
        devs = Ops.get_map(Sound.db_modules, [modname, "mixer"], {})
        setVolume("PCM", card_no, volume) if Builtins.haskey(devs, "PCM")

        storeVolume(card_no)
      end

      Builtins.foreach(
        Convert.convert(params, :from => "map", :to => "map <string, map>")
      ) do |optname, o|
        if Builtins.haskey(options, optname) &&
            Ops.get_string(o, "value", "") !=
              Ops.get_string(options, optname, "")
          possible_values = string2vallist(Ops.get_string(o, "allows", ""))
          err = check_value(
            Ops.get_string(options, optname, ""),
            "string",
            possible_values
          )
          if err != ""
            CommandLine.Print(err)
            next false
          end
          Ops.set(
            save_entry,
            ["options", optname],
            Ops.get_string(options, optname, "")
          )
          modified = true
        end
      end
      if modified
        # save save_entry
        pos = 0
        Sound.modules_conf = Builtins.maplist(Sound.modules_conf) do |card|
          if pos != card_no
            pos = Ops.add(pos, 1)
            next deep_copy(card)
          else
            pos = Ops.add(pos, 1)
            next deep_copy(save_entry)
          end
        end
      end
      modified
    end

    # Handler for setting the volume of sound card
    # @param [Hash] options parameters on command line
    # @return [Boolean] success
    def SetVolumeHandler(options)
      options = deep_copy(options)
      card_no = Builtins.tointeger(Ops.get_string(options, "card", "-1"))
      card_no = 0 if card_no == -1 && Builtins.size(Sound.modules_conf) == 1 # choose first card only if it is the only one
      if card_no == -1
        #error message
        Report.Error(_("You must specify the card number."))
        return false
      end
      save_entry = Ops.get(Sound.modules_conf, card_no)
      if save_entry == nil
        #error message
        Report.Error(_("There is no such sound card."))
        return false
      end

      modname = Ops.get_string(save_entry, "module", "")
      options = Builtins.remove(options, "card")
      pth = Builtins.topath(
        Builtins.sformat(".audio.alsa.cards.%1.channels", card_no)
      )
      channels = Convert.convert(
        Ops.get(Sound.db_modules, [modname, "mixer_elements"], SCR.Dir(pth)),
        :from => "any",
        :to   => "list <string>"
      )
      modified = false

      Builtins.foreach(
        Convert.convert(options, :from => "map", :to => "map <string, string>")
      ) do |channel, val|
        if Builtins.contains(channels, channel)
          volume = Builtins.tointeger(val)
          setVolume(channel, card_no, volume)
          modified = true
        end
      end
      storeVolume(card_no) if modified
      PlayTest(card_no) if Builtins.haskey(options, "play")
      false
    end

    # Handler for listing available channels
    def ListChannelsHandler(options)
      options = deep_copy(options)
      card_no = Builtins.tointeger(Ops.get_string(options, "card", "-1"))
      card_no = 0 if card_no == -1 && Builtins.size(Sound.modules_conf) == 1 # choose first card only if it is the only one
      if card_no == -1
        #error message
        Report.Error(_("You must specify the card number."))
        return false
      end
      save_entry = Ops.get(Sound.modules_conf, card_no)
      if save_entry == nil
        #error message
        Report.Error(_("There is no such sound card."))
        return false
      end

      modname = Ops.get_string(save_entry, "module", "")
      pth = Builtins.topath(
        Builtins.sformat(".audio.alsa.cards.%1.channels", card_no)
      )
      channels = Convert.convert(
        Ops.get(Sound.db_modules, [modname, "mixer_elements"], SCR.Dir(pth)),
        :from => "any",
        :to   => "list <string>"
      )

      Builtins.foreach(
        Convert.convert(channels, :from => "list", :to => "list <string>")
      ) do |ch|
        value = Convert.to_integer(
          SCR.Read(
            Builtins.topath(
              Builtins.sformat(
                ".audio.alsa.cards.%1.channels.%2.volume",
                card_no,
                ch
              )
            )
          )
        )
        CommandLine.Print(Builtins.sformat("%1\t%2", ch, value))
      end

      false
    end
    # Handler for listing available kernel modules for sound
    def ListModulesHandler(options)
      options = deep_copy(options)
      # // kernel module name
      # CommandLine::Print (_("Kernel module") + "\t"
      # 	// kernel module description
      # 	+ _("Description"));
      Builtins.foreach(
        Convert.convert(get_module_names, :from => "list", :to => "list <term>")
      ) do |it|
        id = Ops.get_string(it, [0, 0], "all")
        name = Ops.get_string(it, 1, id)
        next if id == "all"
        space = "\t"
        # if (size (id) < 16)
        #     space = space + "\t";
        # if (size (id) < 8)
        #     space = space + "\t";
        CommandLine.Print(Ops.add(Ops.add(id, space), name)) #	CommandLine::Print (sformat ("%1 (%2)", name, id));
      end

      false
    end
  end
end

Yast::SoundClient.new.main
