# encoding: utf-8

#
# File:
#   options.ycp
#
# Module:
#   Sound
#
# Summary:
#   Module for setting options passed to the module
#
# String corrections by Christian Steinruecken <cstein@suse.de>, 2001/08/01
#
#
# Authors:
#   Dan Vesely <dan@suse.cz>
#   Dan Meszaros <dmeszar@suse.cz>
#
# parameters: 1st: parameter list
#
module Yast
  module SoundOptionsInclude
    def initialize_sound_options(include_target)
      Yast.import "UI"

      textdomain "sound"

      Yast.import "Sound"
      Yast.import "Wizard"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "String"
      Yast.import "Report"

      Yast.include include_target, "sound/ui.rb"
      Yast.include include_target, "sound/routines.rb"
    end

    # checks whether param #1 is if type of param #2
    # @param [String] value value
    # @param [String] type expected type. one of {int, string}
    # @param [Array<String>] poss if poss is nonempty, checks if value is one of them
    # returns error message, empty string if ok
    # @return [String] error message
    def check_value(value, type, poss)
      poss = deep_copy(poss)
      if type == "int"
        if Builtins.tolower(Builtins.substring(value, 0, 2)) == "0x" # hex number
          rest = Builtins.tolower(Builtins.substring(value, 2))
          if Builtins.filterchars(rest, "0123456789abcdef") != rest
            # To translators: popup message, wrong value
            return Builtins.sformat(_("The value: %1 must be a number"), value)
          end # decimal number
        else
          rest = value
          if Builtins.substring(value, 0, 1) == "-" # negative number
            rest = Builtins.substring(value, 1)
          end
          if Builtins.filterchars(rest, "0123456789") != rest
            # To translators: popup message, wrong value
            return Builtins.sformat(_("The value: %1 must be a number"), value)
          end
        end
      elsif type == "string"
        if Builtins.filterchars(
            Builtins.tolower(value),
            "abcdefghijklmnopqrstuvwxyz_0123456789-"
          ) != value
          wrong_pos = Builtins.findfirstnotof(
            Builtins.tolower(value),
            "abcdefghijklmnopqrstuvwxyz_0123456789-"
          )
          wrong_char = Builtins.substring(value, wrong_pos, 1)
          if wrong_char == " "
            # To translators: "space" means blank character
            wrong_char = Ops.add(Ops.add(wrong_char, " "), _("(space)"))
          end
          # To translators: popup message, wrong value
          return Builtins.sformat(_("String cannot contain: %1"), wrong_char)
        end
      end

      # now check for poss list
      if Ops.greater_than(Builtins.size(poss), 0)
        poss_list = []

        poss_list = Builtins.maplist(poss) { |v| value == v } if type != "int"

        if !Builtins.contains(poss_list, true)
          # popup message: wrong value; %1 is list of right values
          return Builtins.sformat(
            _("The value must be one of\n%1"),
            Builtins.mergestring(poss, ",")
          )
        end
      end

      "" # ok :-)
    end

    #  creates itemized table entries,
    #  @param [Array] lm list of maps to take keys from
    #  @param [Array] lk list of keys to look for in 1st param
    #  @return [Array] of items
    def create_table(lm, lk)
      lm = deep_copy(lm)
      lk = deep_copy(lk)
      res = []
      pos = 0
      Builtins.foreach(
        Convert.convert(lm, :from => "list", :to => "list <map <string, any>>")
      ) do |m|
        res = Builtins.add(
          res,
          Item(
            Id(pos),
            Ops.get_string(m, Ops.get_string(lk, 0, ""), ""),
            Ops.get_string(m, Ops.get_string(lk, 1, ""), ""),
            Ops.get_string(m, Ops.get_string(lk, 2, ""), "")
          )
        )
        pos = Ops.add(pos, 1)
      end
      deep_copy(res)
    end

    # parses string (eg. '{{0,2},{0,100,20}}') to a list
    # (in this case [0,1,2,0,20,40,60,80,100])
    # @param [String] input input string
    # @return [Array] of possible values
    def parse_bracket(input)
      inner = input # substring(input, 1, size(input)-2);
      siz = Builtins.size(inner)
      pos = 0
      oldpos = 0
      output = []

      while Ops.less_than(pos, siz)
        if Builtins.substring(inner, pos, 1) == "{"
          oldpos = pos
          pos = Ops.add(pos, 1)
          cnter = 1
          # let's find the pair bracket for '{'
          while Ops.greater_than(cnter, 0) && Ops.less_than(pos, siz)
            if Builtins.substring(inner, pos, 1) == "}"
              cnter = Ops.subtract(cnter, 1)
            elsif Builtins.substring(inner, pos, 1) == "{"
              cnter = Ops.add(cnter, 1)
            end
            pos = Ops.add(pos, 1)
          end
          output = Builtins.add(
            output,
            parse_bracket(
              Builtins.substring(
                inner,
                Ops.add(oldpos, 1),
                Ops.subtract(Ops.subtract(pos, oldpos), 2)
              )
            )
          )
          pos = Ops.add(pos, 1)
        else
          oldpos = pos
          while Builtins.substring(inner, pos, 1) != "," &&
              Ops.less_than(pos, siz)
            pos = Ops.add(pos, 1)
          end
          output = Builtins.add(
            output,
            Builtins.substring(inner, oldpos, Ops.subtract(pos, oldpos))
          )
          pos = Ops.add(pos, 1)
        end
      end
      deep_copy(output)
    end

    # gets an 'modules.generic_string' like options description string
    # and returns a list of possible values
    # @param [String] input string
    # @return [Array] of values
    def string2vallist(input)
      parse_error = false
      l = Builtins.flatten(
        Convert.convert(
          parse_bracket(input),
          :from => "list",
          :to   => "list <list>"
        )
      )

      l = Builtins.maplist(
        Convert.convert(l, :from => "list", :to => "list <list>")
      ) do |e|
        next [] if Builtins.size(e) == 0
        next deep_copy(e) if Builtins.size(e) == 1
        step = 1
        if Builtins.size(e) == 3
          step = Builtins.tointeger(Ops.get_string(e, 2, "1"))
        end
        if Ops.less_than(step, 1)
          parse_error = true
          next []
        end
        hex = false
        if Builtins.regexpmatch(Ops.get_string(e, 1, ""), "^-[0-9]*$") ||
            Builtins.regexpmatch(Ops.get_string(e, 1, ""), "^[0-9]*$")
          hex = false
        elsif Builtins.regexpmatch(Ops.get_string(e, 1, ""), "^-0x[0-9a-fA-F]*") ||
            Builtins.regexpmatch(Ops.get_string(e, 1, ""), "^0x[0-9a-fA-F]*")
          hex = true
        else
          if Builtins.contains(
              ["Disabled", "Enabled"],
              Ops.get_string(e, 1, "")
            )
            next [Ops.get_string(e, 0, "")]
          end
        end
        from = Builtins.tointeger(Ops.get_string(e, 0, ""))
        to = Builtins.tointeger(Ops.get_string(e, 1, ""))
        if Ops.greater_than(Ops.divide(Ops.subtract(to, from), step), 50)
          # too many values :(
          parse_error = true
          next []
        end
        outlist = []
        while Ops.less_or_equal(from, to)
          if hex
            outlist = Builtins.add(outlist, Builtins.tohexstring(from))
          else
            outlist = Builtins.add(outlist, Builtins.sformat("%1", from))
          end
          from = Ops.add(from, step)
        end
        deep_copy(outlist)
      end

      l = Builtins.flatten(
        Convert.convert(l, :from => "list", :to => "list <list>")
      )

      Builtins.y2debug("parse error: %1", input) if parse_error

      Convert.convert(l, :from => "list", :to => "list <string>")
    end

    # default widget when there are no known values
    # @return [Yast::Term] widget
    def defWidget
      # label text
      Label(_("Possible value:\nnot known"))
    end

    # widget for choosing one value from list
    # @param [Array<String>] vals string with values eg. "12,3,4,6"
    # @param [String] preselected string default value (preselected in combo)
    # @return [Yast::Term] combobox widget
    def gen_list(vals, preselected)
      vals = deep_copy(vals)
      vls = Builtins.maplist(vals) { |e| Item(Id(e), e, preselected == e) }
      deep_copy(vls)
    end

    # when the selected option in table is changed, we need to update
    # combo with values
    # @param [String] values list of values
    # @param [String] default_item default item
    # @return [void]
    def getPossibleValues(values, default_item)
      values_list = string2vallist(values)

      if !Builtins.contains(values_list, default_item)
        values_list = Builtins.prepend(values_list, default_item)
      end

      widg = gen_list(values_list, default_item)
      deep_copy(widg)
    end

    def OptionPopup(headline, name, value, new_option, possible_values)
      Builtins.y2milestone("possible_values: %1", possible_values)

      button_box = ButtonBox(
        PushButton(Id(:ok), Opt(:okButton, :default, :key_F10), Label.OKButton),
        PushButton(Id(:cancel), Opt(:cancelButton, :key_F9), Label.CancelButton)
      )

      items = getPossibleValues(possible_values, value)

      content = VBox(
        Heading(headline),
        VSpacing(0.2),
        new_option ?
          VBox(
            Left(TextEntry(Id(:option_name), _("Name of the &Option"), name)),
            VSpacing(0.2)
          ) :
          Empty(),
        Ops.greater_than(Builtins.size(string2vallist(possible_values)), 0) ?
          ComboBox(
            Id(:option_value),
            Opt(:editable, :hstretch),
            Ops.add(new_option ? _("&Value") : _("&Option: "), name),
            items
          ) :
          Left(
            TextEntry(
              Id(:option_value),
              Ops.add(new_option ? _("&Value") : _("&Option: "), name),
              value
            )
          ),
        VSpacing(0.2),
        button_box
      )

      UI.OpenDialog(Opt(:decorated), content)

      ret = nil
      option_name = ""
      option_value = ""

      while true
        ret = UI.UserInput

        # validate the input
        option_name = new_option ?
          Convert.to_string(UI.QueryWidget(Id(:option_name), :Value)) :
          name
        option_value = Convert.to_string(
          UI.QueryWidget(Id(:option_value), :Value)
        )

        # do not validate if the Cancel button has been pressed
        break if ret == :cancel

        # all non-ASCII characters from value
        extra_chars = Builtins.deletechars(option_value, String.CGraph)

        if extra_chars != ""
          Report.Error(
            Builtins.sformat(
              _(
                "Value of the option contains invalid\n" +
                  "characters '%1'.\n" +
                  "\n" +
                  "Enter a valid value."
              ),
              extra_chars
            )
          )
          UI.SetFocus(Id(:option_value))
          next
        end

        # check the option name if it's entered by user
        if new_option
          # all non-ASCII characters from name
          extra_chars = Builtins.deletechars(option_name, String.CGraph)

          if extra_chars != ""
            Report.Error(
              Builtins.sformat(
                _(
                  "Name of the option contains invalid\n" +
                    "characters '%1'.\n" +
                    "\n" +
                    "Enter a valid name."
                ),
                extra_chars
              )
            )
            UI.SetFocus(Id(:option_name))
            next
          end
        end

        break
      end

      UI.CloseDialog

      {
        "ui"           => ret,
        "option_name"  => option_name,
        "option_value" => option_value
      }
    end

    def ChangePopup(option, value, possible_values)
      OptionPopup(_("Change the Option"), option, value, false, possible_values)
    end

    def AddPopup
      OptionPopup(_("Add a New Option"), "", "", true, "")
    end

    # Returns description of card module option
    # @param [Object] arg type of arg can be string or list
    # @return [String] description
    def getDescr(arg)
      arg = deep_copy(arg)
      return Convert.to_string(arg) if Ops.is_string?(arg)
      if Ops.is_list?(arg)
        larg = Convert.to_list(arg)
        return Builtins.sformat(
          Ops.get_string(larg, 0, "%1"),
          Ops.get_string(larg, 1, "")
        )
      end
      _("No description available")
    end


    #	UI controls for options setting dialog
    #
    #  @param [String] cardlabel card model string
    #  @param [Array] itemized_descriptions option list (preformated using
    #		'create_table' with tripples: description, name, value)
    #  @param [String] current_option_name initially selected item name
    #  @param [String] current_option_value value of current option
    #  @return [Yast::Term] options dialog contents
    #  @see #options#OptionsDialog
    def OptionsCon(cardlabel, itemized_descriptions, current_option_name, current_option_value)
      itemized_descriptions = deep_copy(itemized_descriptions)
      HBox(
        HSpacing(3),
        VBox(
          VSquash(Top(Label(Opt(:outputField), cardlabel))),
          VSpacing(),
          Table(
            Id(:table),
            Opt(:notify, :immediate),
            Header(
              # Table header -- option description
              _("Description"),
              # Table header -- option name
              _("Option"),
              # Table header -- value of an option
              Right(_("Value"))
            ),
            itemized_descriptions
          ),
          VSpacing(0.5),
          HBox(
            PushButton(Id(:add), Label.AddButton),
            PushButton(Id(:edit), Label.EditButton),
            PushButton(Id(:delete), Label.DeleteButton),
            HStretch(),
            # restore original option values
            PushButton(Id(:reset), _("R&eset all"))
          ),
          VSpacing(1)
        ),
        HSpacing(3)
      )
    end

    def RefreshDelete(enabled)
      Builtins.y2milestone("Delete button enabled: %1", enabled)
      UI.ChangeWidget(Id(:delete), :Enabled, enabled)

      nil
    end

    def RefreshUI(items, index, enable_delete)
      items = deep_copy(items)
      # refresh the table
      UI.ChangeWidget(Id(:table), :Items, items)

      UI.ChangeWidget(Id(:table), :CurrentItem, index) if index != nil

      RefreshDelete(enable_delete)

      nil
    end

    # displays dialog with card options
    #
    # @param [String] cardlabel string label for the card
    # @param [Hash] opts list. list where each item is map
    #        with keys: name, value, type, default, description.
    #	      values in map are strings
    # @return [Hash] result
    def OptionsDialog(cardlabel, opts, driver)
      opts = deep_copy(opts)
      help_text = Ops.get_string(Sound.STRINGS, "OptionsDialog", "")

      origOptions = deep_copy(opts)

      module_params = get_module_params(driver)
      all_options = Builtins.maplist(
        Convert.convert(
          module_params,
          :from => "map",
          :to   => "map <string, map>"
        )
      ) { |name, o| name }

      options = Builtins.maplist(
        Convert.convert(
          opts,
          :from => "map",
          :to   => "map <string, map <string, any>>"
        )
      ) do |name, o|
        {
          # label: description of option is not available
          "description" => getDescr(
            Ops.get(o, "descr")
          ),
          "name"        => name,
          "value"       => Ops.get_string(o, "value", ""),
          "type"        => Ops.get_string(o, "type", "string"),
          "default"     => Ops.get_string(o, "default", "")
        }
      end

      itemized_descriptions = create_table(
        options,
        ["description", "name", "value"]
      )

      current_option = 0
      current_option_name = Ops.get_string(
        options,
        [current_option, "name"],
        ""
      )

      con = OptionsCon(
        cardlabel,
        itemized_descriptions,
        current_option_name,
        Ops.get_string(options, [current_option, "value"], "")
      )

      # dialog title
      Wizard.SetContents(
        _("Sound Card Advanced Options"),
        con,
        help_text,
        true,
        true
      )

      if Ops.greater_than(Builtins.size(itemized_descriptions), 0)
        UI.ChangeWidget(Id(:table), :CurrentItem, 0)
        UI.SetFocus(Id(:table))
      else
        Popup.Message(_("There are no options for this module"))
      end


      # set initial Delete state
      ui = :table

      ui = :no if Builtins.size(itemized_descriptions) == 0
      begin
        current_option = Convert.to_integer(
          UI.QueryWidget(Id(:table), :CurrentItem)
        )
        curr_opt = Convert.to_term(
          UI.QueryWidget(Id(:table), term(:Item, current_option))
        )
        current_option_name = Ops.get_string(curr_opt, 2, "")
        current_option_value = Ops.get_string(curr_opt, 3, "")

        if ui == :table
          # enable/disable Delete button
          RefreshDelete(!Builtins.contains(all_options, current_option_name))
        elsif ui == :add
          result = AddPopup()
          Builtins.y2milestone("New option: %1", result)

          if Ops.get_symbol(result, "ui", :cancel) == :ok
            # update table
            value = Ops.get_string(result, "option_value", "")
            name = Ops.get_string(result, "option_name", "")

            if name != ""
              index = Builtins.size(itemized_descriptions)

              # remember the new value
              itemized_descriptions = Builtins.add(
                itemized_descriptions,
                Item(Id(index), "", name, value)
              )

              RefreshUI(
                itemized_descriptions,
                index,
                !Builtins.contains(all_options, name)
              )
            end
          end
        elsif ui == :edit
          possible_values = Ops.get_string(
            origOptions,
            [current_option_name, "allows"],
            ""
          )

          while true
            result = ChangePopup(
              current_option_name,
              current_option_value,
              possible_values
            )
            Builtins.y2milestone("Modified option: %1", result)

            if Ops.get_symbol(result, "ui", :cancel) == :ok
              value = Ops.get_string(result, "option_value", "")

              # check the value
              err = check_value(
                value,
                Ops.get_string(options, [current_option, "type"], "string"),
                string2vallist(possible_values)
              )
              if Ops.greater_than(Builtins.size(err), 0) # error - wrong value
                # display message and display the popup again in the loop
                Popup.Message(err)
              else
                UI.ChangeWidget(
                  Id(:table),
                  term(:Item, current_option, 2),
                  value
                )

                # update the value
                tmp = []
                Builtins.maplist(itemized_descriptions) do |e|
                  if current_option == Ops.get_integer(e, [0, 0], 0)
                    tmp = Builtins.add(
                      tmp,
                      Item(
                        Id(current_option),
                        Ops.get_string(e, 1, ""),
                        Ops.get_string(e, 2, ""),
                        value
                      )
                    )
                  else
                    tmp = Builtins.add(tmp, e)
                  end
                end
                itemized_descriptions = deep_copy(tmp)
                break
              end
            else
              break
            end
          end
        elsif ui == :delete
          Builtins.y2milestone("Removed option: %1", current_option_name)

          # update the value
          tmp = []
          Builtins.maplist(itemized_descriptions) do |e|
            if current_option != Ops.get_integer(e, [0, 0], 0)
              tmp = Builtins.add(tmp, e)
            end
          end
          itemized_descriptions = deep_copy(tmp)

          Builtins.y2milestone(
            "itemized_descriptions[0,2]: %1",
            Ops.get_string(itemized_descriptions, [0, 2], "")
          )
          # set Delete status according to the new first item
          RefreshUI(
            itemized_descriptions,
            nil,
            !Builtins.contains(
              all_options,
              Ops.get_string(itemized_descriptions, [0, 2], "")
            )
          )
        elsif ui == :reset &&
            # popup question
            Popup.YesNo(_("Do you really want to reset all values?"))
          i = 0
          while Ops.less_than(i, Builtins.size(itemized_descriptions))
            UI.ChangeWidget(
              Id(:table),
              term(:Item, i, 2),
              Ops.get_string(options, [i, "default"], "")
            )
            # reset the values in items list
            e = Ops.get(itemized_descriptions, i) { Item(Id(i), "", "", "") }
            Ops.set(
              itemized_descriptions,
              i,
              Item(
                Ops.get_term(e, 0) { Id(i) },
                Ops.get_string(e, 1, ""),
                Ops.get_string(e, 2, ""),
                Ops.get_string(options, [i, "default"], "")
              )
            )
            i = Ops.add(i, 1)
          end
        elsif ui == :abort || ui == :cancel
          if ReallyAbort()
            ui = :abort
            break
          end
        end
        ui = Convert.to_symbol(UI.UserInput)
      end until ui == :back || ui == :next || ui == :cancel

      Builtins.y2milestone(
        "ui: %1, itemized_descriptions: %2",
        ui,
        itemized_descriptions
      )

      { "ui" => ui, "return" => itemized_descriptions }
    end

    # just calls options dialog
    # @param [Hash] save_entry map with card configuration
    # @return [Hash] result
    def sound_options(save_entry)
      save_entry = deep_copy(save_entry)
      modname = Ops.get_string(save_entry, "module", "")
      label = Ops.get_string(save_entry, "model", "")
      params = get_module_params(modname)
      Builtins.y2milestone("params: %1", params)
      params = restore_mod_params(
        params,
        Ops.get_map(save_entry, "options", {})
      )
      Builtins.y2milestone("params: %1", params)

      Wizard.RestoreNextButton

      # now show the dialog
      result = OptionsDialog(label, params, modname)
      vals = Ops.get_list(result, "return", [])

      # convert from table entries (items) back to card
      opts = {}
      Builtins.foreach(vals) do |it|
        if Ops.get_string(it, 3, "") != ""
          opts = Builtins.add(
            opts,
            Ops.get_string(it, 2, ""),
            Ops.get_string(it, 3, "")
          )
        end
      end

      Builtins.y2milestone("New options: %1", opts)

      save_entry = Builtins.add(save_entry, "options", opts)

      { "ui" => Ops.get_symbol(result, "ui", :cancel), "return" => save_entry }
    end
  end
end
