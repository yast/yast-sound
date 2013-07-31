# encoding: utf-8

# File:	include/sound/joy_dialog.ycp
# Package:	Joystick configuration
# Summary:	Joystick dialogs
# Authors:	Dan Meszaros <dmeszar@suse.cz>
#		Ladislav Slezak <lslezak@suse.cz>
#		Jiri Suchomel <jsuchome@suse.cz>
module Yast
  module SoundJoyDialogInclude
    def initialize_sound_joy_dialog(include_target)
      Yast.import "UI"

      textdomain "sound"

      Yast.import "Wizard"
      Yast.import "WizardHW"
      Yast.import "Joystick"
      Yast.import "Sound"
      Yast.import "Package"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "String"

      Yast.include include_target, "sound/joysticks.rb"
      Yast.include include_target, "sound/ui.rb"
      Yast.include include_target, "sound/volume_routines.rb"
      Yast.include include_target, "sound/routines.rb"

      # notice about USB devices, used at several places
      @usb_notice = _(
        "USB joysticks do not need any configuration, just connect them."
      )

      @gameport = "Gameport"
    end

    # Update the sound card configuration of joystick
    # @param [Boolean] start	should joystick be used?
    # @return was sound config changed?
    def update_sound_card_joy_config(card_id, start)
      sound_options = Ops.get_map(Sound.modules_conf, [card_id, "options"], {})
      modname = Ops.get_string(Sound.modules_conf, [card_id, "module"], "")
      return false if !Builtins.haskey(Sound.joystick_configuration, modname)
      joy_option = Ops.get_map(Sound.joystick_configuration, modname, {})
      opname = ""
      value = "0"
      # there should be only one entry
      Builtins.foreach(joy_option) do |name, val|
        opname = name
        value = val
      end
      default_value = Ops.get_string(
        Sound.db_modules,
        [modname, "params", opname, "default"],
        "0"
      )

      if start &&
          Ops.get_string(sound_options, opname, default_value) == default_value ||
          !start &&
            Ops.get_string(sound_options, opname, default_value) != default_value
        Ops.set(sound_options, opname, start ? value : default_value)
        Ops.set(Sound.modules_conf, [card_id, "options"], sound_options)
        return true
      end
      false
    end


    # Find index of the sound card in Sound::modules_conf
    # @param sound card map (as returned from .probe.sound)
    # @return integer index in Sound::modules_conf
    def find_sound_card_id(sound_card)
      sound_card = deep_copy(sound_card)
      i = 0
      ret = nil

      Builtins.foreach(Sound.modules_conf) do |card|
        if Ops.get_string(card, "unique_key", "") ==
            Ops.get_string(sound_card, "unique_key", "")
          ret = i
        end
        i = Ops.add(i, 1)
      end

      ret
    end


    # Joystick configuration dialog.
    # Configuration of joystick attached to specified sound card.
    # @param [Fixnum] joy_id Joystick index (in the sysconfig file)
    # @param [Symbol] button Label for `next button: `finish, `ok or `next
    # @return [Symbol] Id of pressed button in the dialog
    def joy_dialog(joy_id, button, sound_card)
      sound_card = deep_copy(sound_card)
      return :back if joy_id == nil

      # find card name
      cardname = Ops.get_string(sound_card, "model", "")

      # dialog header - %1: card name (e.g "Soundblaster 16")
      caption = Builtins.sformat(_("Joystick Configuration - %1"), cardname)

      helptext =
        # help text for joystick configuration 1/4
        _(
          "<P>In this dialog, specify your joystick type. If your\n" +
            "joystick type is not in the list, select <B>Generic Analog Joystick</B>.</p>\n" +
            "<p>You will not find any USB joysticks here. If you have a USB device, just plug in the joystick and start using it.</P>\n"
        )

      joy = Ops.get_map(Joystick.joystick, joy_id, {})
      mod = Ops.get_string(joy, "model", "")

      Builtins.y2milestone("Joystick configuration started, index: %1", joy_id)

      # translate model from /etc/sysconfig/joystick
      if mod == Joystick.generic_joystick
        mod = Joystick.generic_joystick_translated
      end

      # list of joystick drivers and models
      joylist = Builtins.maplist(@JoystickDB) do |modname, models|
        Builtins.maplist(models) { |model| [modname, model] }
      end
      joylist = Builtins.flatten(
        Convert.convert(joylist, :from => "list", :to => "list <list>")
      )

      joylist = Builtins.sort(
        Convert.convert(joylist, :from => "list", :to => "list <list>")
      ) do |j1, j2|
        Ops.less_than(Ops.get_string(j1, 1, ""), Ops.get_string(j2, 1, ""))
      end

      joylist = Builtins.prepend(
        joylist,
        ["analog", Joystick.generic_joystick_translated]
      )

      Builtins.y2debug("joylist: %1", joylist)

      index = 0
      boxitems = []

      Builtins.foreach(
        Convert.convert(joylist, :from => "list", :to => "list <list>")
      ) do |l|
        model = Ops.get_string(l, 1, "")
        if mod == model
          # preselect item
          boxitems = Builtins.add(boxitems, Item(Id(index), model, true))
        else
          boxitems = Builtins.add(boxitems, Item(Id(index), model))
        end
        index = Ops.add(index, 1)
      end

      Builtins.y2debug("for widget: %1", boxitems)

      contents = VBox(
        VSpacing(3),
        HBox(
          HSpacing(3),
          # label above list of joystick types
          SelectionBox(Id(:os), _("&Select your joystick type:"), boxitems),
          HSpacing(3)
        ),
        VSpacing(3)
      )

      nextbutton = {
        :finish => Label.FinishButton,
        :ok     => Label.OKButton,
        :next   => Label.NextButton
      }

      Wizard.OpenNextBackDialog
      Wizard.SetContents(caption, contents, helptext, true, true)
      Wizard.SetNextButton(:next, Ops.get_string(nextbutton, button) do
        Label.NextButton
      end)
      Wizard.HideBackButton if !Mode.installation

      s = nil
      begin
        s = Convert.to_symbol(UI.UserInput)

        s = :skip_event if s == :abort && !ReallyAbort()

        if s == :next && UI.QueryWidget(Id(:os), :CurrentItem) == nil
          # warning message - user did not select any joystick type
          Popup.Warning(
            _(
              "Select the joystick type from the list\n" +
                "before pressing Next.\n" +
                "\n"
            )
          )
          s = :skip
        end
      end while !Builtins.contains([:next, :back, :abort, :cancel], s)

      if s == :next
        card_id = find_sound_card_id(sound_card)
        modname = Ops.get_string(Sound.modules_conf, [card_id, "module"], "")
        joy_entry = Sound.GetJoystickSettings(modname)
        joymodidx = Convert.to_integer(UI.QueryWidget(Id(:os), :CurrentItem))
        joymod = Ops.get_string(joylist, [joymodidx, 0], "")

        if joymod == ""
          # selected none joystick
          joy_entry = {}
        else
          model = Ops.get_string(joylist, [joymodidx, 1], "")

          # do not translate model in /etc/sysconfig/joystick
          if model == Joystick.generic_joystick_translated
            model = Joystick.generic_joystick
          end

          Builtins.y2debug("selected joy module: %1, model: %2", joymod, model)

          Ops.set(joy_entry, "JOYSTICK_MODULE", joymod)
          Ops.set(joy_entry, "model", model)
          Ops.set(
            joy_entry,
            "attached_to",
            Ops.get_string(sound_card, "unique_key", "")
          )
        end
        update_sound_card_joy_config(card_id, joymod != "")

        Ops.set(Joystick.joystick, joy_id, joy_entry)
        Joystick.modified = true

        Builtins.y2milestone("New joystick configuration: %1", joy_entry)
      end

      # restore previous `next button label (only if label was not Finish)
      Wizard.RestoreNextButton if button != :finish

      Wizard.RestoreBackButton if !Mode.installation
      Wizard.CloseDialog

      s
    end

    # Create unique widget id for a broken joystick config
    # @param index index of non-working joystick configuration
    # @return string the ID
    def broken_id(index)
      Builtins.sformat("broken_%1", index)
    end

    # Belogs the ID to a broken joystick?
    # @param id
    # @return boolean true if the ID belongs to a broken configuration
    def is_broken(id)
      Builtins.regexpmatch(id, "broken_[0-9]+")
    end

    # Get the joystick index from broken ID string
    # @param id
    # @return integer the ID or nil if the ID do not belong to a broken configuration
    def broken_index(id)
      num = Builtins.regexpsub(id, "broken_([0-9]+)", "\\1")

      return nil if num == nil

      Builtins.tointeger(num)
    end

    # Get details about the joustick bus
    # @param js Joystick device map
    # @param soundcards List of detected soundcards
    # @return string Bus description
    def joystick_bus_details(js, soundcards)
      js = deep_copy(js)
      soundcards = deep_copy(soundcards)
      ret = Ops.get_string(js, "bus", "")

      if ret == @gameport
        unique_key = Ops.get_string(js, "parent_unique_key", "")

        card = Builtins.find(soundcards) do |c|
          Ops.get_string(c, "unique_key", "") == unique_key
        end

        if card != nil
          # joystick details, %1 is the sound card name to which is the joystick connected
          ret = Builtins.sformat(
            _("%1 (%2)"),
            ret,
            Ops.get_string(card, "model", "")
          )
        end
      end

      ret
    end

    # Create content for the joystick overview table
    # @return list<map<string,any>> content for WizardHW::SetContents() function
    def joystick_table
      content = []
      soundcards = Convert.convert(
        SCR.Read(path(".probe.sound")),
        :from => "any",
        :to   => "list <map>"
      )
      found_joysticks = []

      Builtins.foreach(Joystick.Detected) do |js|
        Builtins.y2milestone("Adding joystick to table: %1", js)
        device = Ops.get_string(js, "dev_name2", "")
        model = Ops.get_string(js, "model", "")
        descr = []
        if Ops.greater_than(Ops.get_integer(js, ["detail", "axes"], 0), 0)
          descr = Builtins.add(
            descr,
            Builtins.sformat(
              _("Number of axes: %1"),
              Ops.get_integer(js, ["detail", "axes"], 0)
            )
          )
        end
        if Ops.greater_than(Ops.get_integer(js, ["detail", "buttons"], 0), 0)
          descr = Builtins.add(
            descr,
            Builtins.sformat(
              _("Number of buttons: %1"),
              Ops.get_integer(js, ["detail", "buttons"], 0)
            )
          )
        end
        bus = Ops.get_string(js, "bus", "")
        # add the sound card name for gameport joysticks
        if bus == @gameport &&
            Ops.greater_than(
              Builtins.size(Ops.get_string(js, "parent_unique_key", "")),
              0
            )
          bus = joystick_bus_details(js, soundcards)
          unique_key = Ops.get_string(js, "parent_unique_key", "")

          i2 = 0
          joy_index = nil

          while Ops.less_than(i2, 4)
            jconf = Ops.get_map(Joystick.joystick, i2, {})

            if Ops.get_string(jconf, "attached_to", "") == unique_key
              joy_index = i2
              break
            end

            i2 = Ops.add(i2, 1)
          end

          if joy_index != nil
            j_config = Builtins.find(
              Convert.convert(
                Joystick.joystick,
                :from => "list",
                :to   => "list <map>"
              )
            ) do |j2|
              Ops.get_string(j2, "attached_to", "") == unique_key
            end
            config_model = Ops.get_string(j_config, "model", "")

            if config_model != nil && config_model != ""
              Builtins.y2milestone("Adding joystick model: %1", config_model)

              model = Builtins.sformat("%1 (%2)", model, config_model)
            end

            found_joysticks = Builtins.add(found_joysticks, joy_index)
          end
        end
        j = {
          "id"          => device,
          "table_descr" => [model, device, bus],
          "rich_descr"  => WizardHW.CreateRichTextDescription(model, descr)
        }
        content = Builtins.add(content, j)
      end

      Builtins.y2milestone("Found joysticks at indices: %1", found_joysticks)

      i = 0
      # check non-working joystick configurations
      Builtins.foreach(
        Convert.convert(Joystick.joystick, :from => "list", :to => "list <map>")
      ) do |js|
        if !Builtins.contains(found_joysticks, i) &&
            Ops.get_string(js, "JOYSTICK_MODULE", "") != ""
          Builtins.y2milestone(
            "Found inactive joystick configuration at index %1: %2",
            i,
            js
          )
          model = Ops.get_locale(js, "model", _("Unknown joystick model"))
          unique_key = Ops.get_string(js, "attached_to", "")
          bus = @gameport

          card = Builtins.find(soundcards) do |c|
            Ops.get_string(c, "unique_key", "") == unique_key
          end

          if card != nil
            # joystick details, %1 is the sound card name to which is the joystick connected
            bus = Builtins.sformat(
              "%1 (%2)",
              bus,
              Ops.get_string(card, "model", "")
            )
          end

          j = {
            "id"          => broken_id(i),
            # the joystick device was not found (the joystick is probably disconnected)
            "table_descr" => [
              model,
              _("<not found>"),
              bus
            ],
            # add red warning about invalid configuration to the model name (%1)
            "rich_descr"  => WizardHW.CreateRichTextDescription(
              Builtins.sformat(
                _("%1 - <font color=\"red\">Invalid configuration<font>"),
                model
              ),
              [
                # help text
                _(
                  "The configuration is not active - either the joystick is not connected or a wrong driver is used"
                ),
                # help text
                _(
                  "Press <b>Edit</b> to change the joystick driver or <b>Delete</b> to remove the configuration"
                )
              ]
            )
          }

          content = Builtins.add(content, j)
        end
        i = Ops.add(i, 1)
      end

      deep_copy(content)
    end

    # Find detected joystick with requested device name
    # @param device joystick device name (e.g. "/dev/input/js0")
    # @return map joystick map returned from .probe.joystick agent
    def find_joystick(device)
      Builtins.find(Joystick.Detected) do |j|
        Ops.get_string(j, "dev_name2", "") == device
      end
    end

    # Display and run the joystick test dialog
    # @param device device name of the joystick to test (e.g. "/dev/input/js0")
    def test_joystick(device)
      js = find_joystick(device)
      if js == nil
        Builtins.y2error("Cannot find joystick %1", device)
        return
      end

      # generate appropriate dialog for the joystick
      joy_attrib = VBox()
      min = -32767 # see js_event.value in linux/joystick.h
      max = 32767
      i = 0

      while Ops.less_than(i, Ops.get_integer(js, ["detail", "axes"], 0))
        # progress bar label
        widget_name = Builtins.sformat(_("Axis %1"), i)
        widget_id = Builtins.sformat("Axis %1", i)

        if UI.HasSpecialWidget(:Slider)
          joy_attrib = Builtins.add(
            joy_attrib,
            Slider(Id(widget_id), Opt(:disabled), widget_name, min, max, 0)
          )
        else
          joy_attrib = Builtins.add(
            joy_attrib,
            IntField(Id(widget_id), Opt(:disabled), widget_name, min, max, 0)
          )
        end

        joy_attrib = Builtins.add(joy_attrib, VSpacing(0.3))
        i = Ops.add(i, 1)
      end

      joy_buttons = HBox()
      not_pressed = "    "
      pressed = UI.Glyph(:CheckMark)

      i = 0
      while Ops.less_than(i, Ops.get_integer(js, ["detail", "buttons"], 0))
        # label
        widget_name = Builtins.sformat(_("Button %1"), i)
        widget_id = Builtins.sformat("Button %1", i)
        joy_buttons = Builtins.add(
          joy_buttons,
          Label(Id(widget_id), Ops.add(Ops.add(widget_name, " "), not_pressed))
        )
        joy_buttons = Builtins.add(joy_buttons, HSpacing(2))
        i = Ops.add(i, 1)
      end
      joy_attrib = Builtins.add(joy_attrib, joy_buttons)

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1.5),
          VSpacing(18),
          VBox(
            HSpacing(50),
            VSpacing(0.5),
            # Popup label
            Heading(_("Joystick Test")),
            VSpacing(0.5),
            # label - joystick details (%1 is model name, %2 is bus name)
            Left(
              Label(
                Builtins.sformat(
                  _("Joystick: %1, attached to: %2"),
                  Ops.get_string(js, "model", ""),
                  joystick_bus_details(
                    js,
                    Convert.convert(
                      SCR.Read(path(".probe.sound")),
                      :from => "any",
                      :to   => "list <map>"
                    )
                  )
                )
              )
            ),
            #`VSpacing(0.5),
            joy_attrib,
            VSpacing(1),
            PushButton(Id(:done), Opt(:default), Label.OKButton),
            VSpacing(1)
          ),
          HSpacing(1.5)
        )
      )

      command = Builtins.sformat(
        "/usr/bin/jstest --event '%1'",
        String.Quote(device)
      )
      process = Convert.to_integer(
        SCR.Execute(path(".process.start_shell"), command)
      )

      ret = nil
      begin
        if SCR.Read(path(".process.running"), process) == false
          Builtins.y2error("Unexpected exit")
          break
        end

        out = Convert.to_string(SCR.Read(path(".process.read_line"), process))

        if out != nil
          Builtins.y2debug("jstest output: %1", out)

          # the output is like "Event: type 2, time 26263500, number 0, value 0"
          type_str = Builtins.regexpsub(out, "type ([0-9]+)", "\\1")
          number_str = Builtins.regexpsub(out, "number ([0-9]+)", "\\1")
          value_str = Builtins.regexpsub(out, "value ([-]{0,1}[0-9]+)", "\\1")

          if type_str != nil && number_str != nil && value_str != nil
            type = Builtins.tointeger(type_str)
            number = Builtins.tointeger(number_str)
            value = Builtins.tointeger(value_str)

            if type == 1
              # button state changed
              UI.ChangeWidget(
                Id(Builtins.sformat("Button %1", number)),
                :Value,
                Ops.add(
                  Ops.add(
                    # label text ("Button" is joystick's button no. %1)
                    Builtins.sformat(_("Button %1"), number),
                    " "
                  ),
                  value == 1 ? pressed : not_pressed
                )
              )
            elsif type == 2
              # change in some axis
              UI.ChangeWidget(
                Id(Builtins.sformat("Axis %1", number)),
                :Value,
                value
              )
            end
          end
        end
        ret = Convert.to_symbol(UI.PollInput)
      end while ret == nil

      Builtins.y2milestone("killing")
      SCR.Execute(path(".process.kill"), process)

      # release the process from the agent
      SCR.Execute(path(".process.release"), process)

      UI.CloseDialog

      nil
    end

    # Return list of sound cards with gameport that do not have any joystick configured
    # @param gameport_cards list of all cards with gameport
    # @return list list of cards from gameport_cards that don't have any joystick configured
    def unconfigured_sound_cards(gameport_cards)
      gameport_cards = deep_copy(gameport_cards)
      ret = Builtins.filter(
        Convert.convert(gameport_cards, :from => "list", :to => "list <map>")
      ) do |card|
        Builtins.find(
          Convert.convert(
            Joystick.joystick,
            :from => "list",
            :to   => "list <map>"
          )
        ) do |j|
          Ops.get_string(j, "attached_to", "") ==
            Ops.get_string(card, "unique_key", "")
        end == nil
      end

      Builtins.y2milestone("Unconfigured gameport cards: %1", ret)
      deep_copy(ret)
    end

    # Display dialog for selecting sound card to configure
    # @param gameport_cards available sound cards with gameport
    # @returen map the selected card (one from gameport_cards) or nil if [Cancel] was pressed
    def select_sound_card(gameport_cards)
      gameport_cards = deep_copy(gameport_cards)
      i = -1
      tcont = Builtins.maplist(
        Convert.convert(gameport_cards, :from => "list", :to => "list <map>")
      ) do |card|
        i = Ops.add(i, 1)
        Item(Id(i), Ops.get_string(card, "model", "Sound card"))
      end

      dialog = HBox(
        VSpacing(10),
        VBox(
          Heading(_("Sound Cards with Joystick Support")),
          Table(
            Id(:cards),
            Header(
              # table header (card name)
              _("Sound card")
            ),
            tcont
          ),
          Label(
            _("To add an USB joystick close this dialog and just connect it.")
          ),
          ButtonBox(
            # button label
            PushButton(Id(:ok), _("&Configure joystick")),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      UI.OpenDialog(Opt(:decorated), dialog)

      # preselect the first card
      UI.ChangeWidget(Id(:cards), :CurrentItem, 0)

      ret = Convert.to_symbol(UI.UserInput)

      joy_card = Convert.to_integer(UI.QueryWidget(Id(:cards), :CurrentItem))
      Builtins.y2milestone("Selected sound card: %1", joy_card)

      UI.CloseDialog

      if ret == :cancel || ret == :abort
        Builtins.y2milestone("Sound card selection canceled")
        return nil
      end

      Ops.get_map(gameport_cards, joy_card, {})
    end

    # Is the selected joystick connected via USB?
    # @param device joystick device name (e.g. "/dev/input/js0")
    # @reurn boolean true if the device is an USB joystick
    def is_usb(device)
      js = find_joystick(device)
      return false if js == nil

      Ops.get_string(js, "bus", "") == "USB"
    end

    # Find joystick index which is attached to a sound card
    # @param parent_id the unique key of the sound card
    # @return the index or nil if the sound card was not found
    def find_joystick_number(parent_id)
      i = 0
      found = false

      Builtins.foreach(
        Convert.convert(Joystick.joystick, :from => "list", :to => "list <map>")
      ) do |j|
        if Ops.get_string(j, "attached_to", "") == parent_id
          found = true
          raise Break
        end
        i = Ops.add(i, 1)
      end

      ret = i

      ret = nil if !found
      Builtins.y2milestone(
        "Joystick index with parent id %1: %2",
        parent_id,
        ret
      )

      ret
    end

    # Find the index of the first unused joystick configuration
    # @return integer the index or nil when all configs are already used
    def find_free_number
      i = 0
      found = false

      Builtins.foreach(
        Convert.convert(Joystick.joystick, :from => "list", :to => "list <map>")
      ) do |j|
        if Ops.get_string(j, "JOYSTICK_MODULE", "") == ""
          found = true
          raise Break
        end
        i = Ops.add(i, 1)
      end

      ret = i

      ret = nil if !found
      Builtins.y2milestone("Unconfigured joystick at index: %1", ret)

      ret
    end

    # Save one joystick configuration and restart the joystick service to reload drivers
    # @param num index of the joystick configuration to change
    def restart_joystick(num)
      # restart joystick service to reload the driver
      Joystick.Stop
      Joystick.SaveOneJoystick(num)
      Joystick.WriteConfig
      Joystick.StartAndEnable

      # re-detect attached joysticks
      Joystick.Detect

      nil
    end

    # Refresh the joystick table in the main configuration dialog
    def refresh_table
      items = joystick_table
      WizardHW.SetContents(items)

      nil
    end

    # Return the list of detected sound cards that support gameport
    # @return list<map> list of devices (as returned by .probe.sound agent)
    def sound_cards_with_joystick
      sound_cards = Convert.convert(
        SCR.Read(path(".probe.sound")),
        :from => "any",
        :to   => "list <map>"
      )

      sound_cards = Builtins.filter(sound_cards) do |sound_card|
        driver = Ops.get_string(get_module(sound_card), "name", "")
        if driver == nil || driver == ""
          driver = String.Replace(
            Ops.get_string(sound_card, "driver_module", ""),
            "_",
            "-"
          )
        end
        Ops.get_map(Sound.db_modules, [driver, "joystick"], {}) != {}
      end

      deep_copy(sound_cards)
    end

    # Return modification time of /dev/input directory
    # @return integer mtime in seconds
    def input_mtime
      Ops.get_integer(
        Convert.to_map(SCR.Read(path(".target.stat"), "/dev/input")),
        "mtime",
        0
      )
    end

    # Display and run the main joystick dialog
    # @return symbol the final user input
    def joystick_overview
      extra_buttons = [
        # menu item
        [:test, _("&Test selected joystick...")]
      ]

      # dialog title
      WizardHW.CreateHWDialog(
        _("Joysticks"),
        Ops.add(
          Ops.add(
            # help text
            _("<p><big><b>Joysticks</b></big></p>") +
              _("<p>Here is an overview of the detected joysticks.</p>") +
              _(
                "<p>To configure a new joystick connected to a Gameport press <b>Add</b> button.</p>"
              ) + "<p>",
            @usb_notice
          ),
          "</p>"
        ),
        # table header
        [_("Model"), _("Device name"), _("Attached to")],
        extra_buttons
      )

      # create description for WizardHW
      items = joystick_table
      Builtins.y2debug("items: %1", items)

      WizardHW.SetContents(items)

      Wizard.SetNextButton(:next, Label.FinishButton)

      ret = :dummy
      mtime = input_mtime

      while !Builtins.contains([:abort, :back, :next], ret)
        ret = Convert.to_symbol(UI.TimeoutUserInput(2000))

        # no user input, check for hotplug changes
        if ret == :timeout
          current_mtime = input_mtime

          if current_mtime != mtime
            # /dev/input has changed - rescan joysticks and refresh the table
            Builtins.y2milestone(
              "/dev/input has been changed, rescanning devices..."
            )

            Joystick.Detect
            refresh_table

            mtime = current_mtime
          end

          next
        end

        ret = :abort if ret == :cancel

        device = WizardHW.SelectedItem

        if ret == :add
          jcards = sound_cards_with_joystick
          Builtins.y2milestone("Sound cards with gameport: %1", jcards)

          # no sound card with gameport
          if Builtins.size(jcards) == 0
            message = Ops.add(
              _("There is no soundcard with joystick support (gameport).") + "\n",
              @usb_notice
            )

            Popup.Message(message)
          else
            # remove configured cards with joystick
            unconfigured = unconfigured_sound_cards(jcards)
            Builtins.y2milestone(
              "Gamport sound cards without joystick: %1",
              unconfigured
            )

            if Builtins.size(unconfigured) == 0
              message = Ops.add(
                _("There is no soundcard with unconfigured joystick.") + "\n",
                @usb_notice
              )

              Popup.Message(message)
            else
              # if there is just one card just use it otherwise ask user
              card = Builtins.size(unconfigured) == 1 ?
                Ops.get_map(unconfigured, 0, {}) :
                select_sound_card(unconfigured)
              joy_index = find_free_number

              # selection canceled?
              if card != nil
                joy_dialog(joy_index, :ok, card)

                restart_joystick(joy_index)

                refresh_table
              end
            end
          end
        elsif ret == :edit
          if is_usb(device)
            # popup message - pressed [Edit] when an USB joystick is selected
            Popup.Message("USB joysticks do not need any configuration.")
          else
            num = nil
            key = ""

            if is_broken(device)
              num = broken_index(device)
              j = Ops.get_map(Joystick.joystick, num, {})
              key = Ops.get_string(j, "attached_to", "")
            else
              key = Ops.get_string(
                find_joystick(device),
                "parent_unique_key",
                ""
              )
              num = find_joystick_number(key)
            end

            soundcards = Convert.convert(
              SCR.Read(path(".probe.sound")),
              :from => "any",
              :to   => "list <map>"
            )
            card = Builtins.find(soundcards) do |c|
              Ops.get_string(c, "unique_key", "") == key
            end
            ui = joy_dialog(num, :ok, card)

            if ui == :next || ui == :finish
              # restart joystick service to reload the driver
              restart_joystick(num)

              # refresh table content
              refresh_table
            end
          end
        elsif ret == :delete
          if is_usb(device)
            # popup message - pressed [Delete] when an USB joystick is selected
            Popup.Message("USB joysticks cannot be deleted, just unplug them.")
          else
            num = is_broken(device) ?
              broken_index(device) :
              find_joystick_number(
                Ops.get_string(find_joystick(device), "parent_unique_key", "")
              )

            Builtins.y2milestone("Deleting joystick %1 (index %2)", device, num)

            # modify joystick config
            Ops.set(Joystick.joystick, num, {})
            Joystick.modified = true

            # restart joystick service to reload the driver
            restart_joystick(num)

            # refresh table content
            refresh_table
          end
        elsif ret == :test
          if is_broken(device)
            # error popup
            Popup.Error(
              _(
                "The selected joystick configuration is not active.\n" +
                  "\n" +
                  "The joystick cannot be tested."
              )
            )
          else
            test_joystick(device)
          end
        end
      end

      Builtins.y2milestone("Final joystick config: %1", Joystick.joystick)
      Builtins.y2milestone("Joystick overview result: %1", ret)

      ret
    end
  end
end
