# encoding: utf-8

# File:
#   manual.ycp
#
# Module:
#   Sound
#
# Summary:
#   Module for manual selection of sound card from the database
#
# Authors:
#   Dan Vesely <dan@suse.cz>
#   Dan Meszaros <dmeszar@suse.cz>
#
# String corrections by Christian Steinruecken <cstein@suse.de>, 2001/08/01
#
#
#
module Yast
  module SoundManualInclude
    def initialize_sound_manual(include_target)
      Yast.import "UI"

      textdomain "sound"
      Yast.import "Wizard"
      Yast.import "Sound"
      Yast.import "Label"

      Yast.include include_target, "sound/routines.rb"
      Yast.include include_target, "sound/ui.rb"
    end

    # returns module name for a given card model
    # @param [String] cardname string card name
    # @return [String] module name
    def get_module_by_cardname(cardname)
      if !Sound.use_alsa
        # the name is in the form sformat("Sound card (%1)", key)
        card_l = Builtins.splitstring(cardname, "()")
        return Ops.get_string(card_l, 1, "")
      end

      i = -1
      Builtins.foreach(
        Convert.convert(
          Sound.db_cards,
          :from => "map",
          :to   => "map <integer, list>"
        )
      ) do |module_index, names|
        i = module_index if Builtins.contains(names, cardname)
      end
      Ops.get_string(Sound.db_module_index, i, "error")
    end

    # returns vendor name for a given card model
    # @param [String] cardname string card name
    # @return [String] vendor name
    def get_vendor_by_cardname(cardname)
      return "" if !Sound.use_alsa

      card_l = Builtins.splitstring(cardname, ",")
      vendor = Ops.get_string(
        card_l,
        Ops.subtract(Builtins.size(card_l), 1),
        ""
      )
      return "other" if Builtins.size(card_l) == 1
      if Builtins.substring(vendor, 0, 1) == " "
        vendor = Builtins.substring(vendor, 1)
      end
      vendor = "other" if !Builtins.haskey(Sound.db_vendors, vendor)
      vendor
    end

    # returns list of card vendors
    # @return [Array] of items with vendors (into table)
    def get_vendor_names
      return [] if !Sound.use_alsa

      Sound.LoadDatabase(true)
      items = Builtins.maplist(
        Convert.convert(
          Sound.db_vendors,
          :from => "map",
          :to   => "map <string, list>"
        )
      ) do |v, cs|
        if v == "other"
          # table entry (vendor was not defined)
          next Item(Id(v), _("Other"))
        end
        Item(Id(v), v)
      end
      # table entry (all vendors)
      Builtins.prepend(items, Item(Id("all"), _("All")))
    end

    # Update the settings for manualy choosed card: get the default options
    # and check if it tha card wasn't detected
    # @param [Hash] card_map the current card (map with at least "module" entry)
    # @return updated map of current card
    def update_manual_card(card_map)
      card_map = deep_copy(card_map)
      uniq_k = isa_uniq
      label = Ops.get_string(card_map, "model", "Sound card")
      modname = Ops.get_string(card_map, "module", "")

      # set default values for options
      optlist = Ops.get_map(Sound.db_modules, modname, {})
      options = {}
      Builtins.maplist(Ops.get_map(optlist, "params", {})) do |name, val|
        if Builtins.haskey(val, "default")
          options = Builtins.add(
            options,
            name,
            Ops.get_string(val, "default", "")
          )
        end
      end

      # if user selects the soundcard that has been already autodetected,
      # use the detected card instead of manual selection (because it causes
      # some problems with uniq. keys)
      det_cards = Builtins.filter(Sound.unconfigured_cards) do |card|
        Ops.get(card, "module") == modname
      end

      Builtins.y2debug("%1", det_cards)
      if Ops.greater_than(Builtins.size(det_cards), 0)
        label = Ops.get_string(det_cards, [0, "model"], label)
        uniq_k = Ops.get_string(det_cards, [0, "unique_key"], uniq_k)
      end

      uniques = Builtins.maplist(Sound.modules_conf) do |c|
        Ops.get_string(c, "unique_key", "")
      end

      # check whether the uniqe key is already used
      idx = 0
      while Builtins.contains(uniques, uniq_k)
        uniq_k = Ops.add("uniq.unknownkey", Builtins.tostring(idx))
        idx = Ops.add(idx, 1)
      end

      {
        "module"     => modname,
        "model"      => label,
        "unique_key" => uniq_k,
        "options"    => options
      }
    end

    # Dialog for manual adding the sound card
    # (shows the lists of Vendors/Drivers and Models)
    #  @return [Hash] result
    def ManualDialog
      helptext = Ops.get_string(Sound.STRINGS, "ManualDialog", "")
      keys = Sound.use_alsa ? "vendors" : "modules"

      vendor_names = get_vendor_names
      module_names = get_module_names
      keys_names = deep_copy(vendor_names)
      curr_key = Sound.curr_vendor
      if keys == "modules"
        curr_key = Sound.curr_driver
        keys_names = deep_copy(module_names)
      end
      if !Sound.use_alsa && curr_key == ""
        Sound.curr_driver = Ops.get_string(module_names, 0, "")
        curr_key = Sound.curr_driver
      end
      card_names = get_card_names(curr_key, keys)
      contents = VBox(
        HBox(
          ReplacePoint(
            Id(:rep_keys),
            SelectionBox(
              Id(:sel_keys),
              Opt(:notify, :immediate),
              keys == "vendors" ?
                # selection box title
                _("Sound Card &Vendor") :
                # selection box title
                _("Sound card &driver"),
              keys_names
            )
          ),
          ReplacePoint(
            Id(:rep_mod),
            SelectionBox(
              Id(:sel_mod),
              Opt(:notify),
              # selection box title
              _("Sound card &model"),
              card_names
            )
          )
        ),
        Sound.use_alsa ?
          Left(
            CheckBox(
              Id(:ch_sets),
              Opt(:notify),
              # checkbox label
              _("Show List of Kernel Modules"),
              false
            )
          ) :
          VSpacing(),
        # input field - label
        InputField(Id(:search), Opt(:notify, :hstretch), _("&Search")),
        VSpacing()
      )

      # dialog title
      Wizard.SetContentsButtons(
        _("Manual Sound Card Selection"),
        contents,
        helptext,
        Label.BackButton,
        Label.NextButton
      )

      if Sound.curr_model == ""
        Sound.curr_model = Ops.get_string(card_names, 0, "")
      end
      curr_key = Ops.get_string(keys_names, [0, 1], "") if curr_key == ""

      if keys == "vendors"
        Sound.curr_vendor = curr_key
      else
        Sound.curr_driver = curr_key
      end

      UI.ChangeWidget(Id(:sel_keys), :CurrentItem, curr_key)
      UI.ChangeWidget(Id(:sel_mod), :CurrentItem, Sound.curr_model)

      UI.SetFocus(Id(:sel_keys))
      ui = nil
      begin
        ui = Convert.to_symbol(UI.UserInput)

        if ui == :ch_sets
          mods = Convert.to_boolean(UI.QueryWidget(Id(:ch_sets), :Value))

          key = Convert.to_string(UI.QueryWidget(Id(:sel_keys), :CurrentItem))
          model = Convert.to_string(UI.QueryWidget(Id(:sel_mod), :CurrentItem))
          new_key = key
          new_model = model

          if mods && keys == "vendors"
            if key != "other" && key != "all"
              if !Builtins.issubstring(model, Ops.add(", ", key))
                new_model = Builtins.sformat("%1, %2", model, key)
              end
            end
            new_key = get_module_by_cardname(new_model)
            keys = "modules"
          elsif !mods && keys == "modules"
            new_key = get_vendor_by_cardname(model)
            keys = "vendors"
            card_l = Builtins.splitstring(model, ",")
            new_model = Ops.get_string(card_l, 0, model)
          else
            next
          end

          keys_names = keys == "vendors" ? vendor_names : module_names

          UI.ChangeWidget(Id(:sel_keys), :Items, keys_names)

          UI.ChangeWidget(Id(:sel_keys), :CurrentItem, new_key)
          Sound.curr_model = new_model
          ui = :sel_keys # we must adapt the list of card names
        end
        if ui == :sel_keys
          card_names = get_card_names(
            Convert.to_string(UI.QueryWidget(Id(:sel_keys), :CurrentItem)),
            keys
          )

          UI.ChangeWidget(Id(:sel_mod), :Items, card_names)

          if Builtins.contains(card_names, Sound.curr_model)
            UI.ChangeWidget(Id(:sel_mod), :CurrentItem, Sound.curr_model)
          else
            UI.ChangeWidget(
              Id(:sel_mod),
              :CurrentItem,
              Ops.get_string(card_names, 0, "")
            )
          end
        elsif ui == :search
          entry = Convert.to_string(UI.QueryWidget(Id(:search), :Value))
          card_id = search_card_id(entry)
          card_names = get_card_names("all", keys)
          # always "all" field in vendors list
          UI.ChangeWidget(Id(:sel_keys), :CurrentItem, "all")
          if Ops.greater_or_equal(card_id, 0)
            UI.ChangeWidget(Id(:sel_mod), :Items, card_names)

            UI.ChangeWidget(
              Id(:sel_mod),
              :CurrentItem,
              Ops.get_string(card_names, card_id, "")
            )
          end
        elsif ui == :abort || ui == :cancel
          ui = ReallyAbort() ? :abort : :dummy
        end
      end while !Builtins.contains([:next, :back, :abort], ui)

      ret = { "ui" => ui }


      if ui == :next
        key = Convert.to_string(UI.QueryWidget(Id(:sel_keys), :CurrentItem))
        model = Convert.to_string(UI.QueryWidget(Id(:sel_mod), :CurrentItem))
        longmodel = model
        vendor = keys == "vendors" ? key : get_vendor_by_cardname(model)

        if Sound.use_alsa
          if vendor != "all"
            # vendor is included in model name
            if vendor != "other" &&
                !Builtins.issubstring(model, Ops.add(", ", vendor))
              longmodel = Builtins.sformat("%1, %2", model, vendor)
            end
          else
            vendor = get_vendor_by_cardname(model)
          end
          if Builtins.issubstring(model, Ops.add(", ", vendor))
            card_l = Builtins.splitstring(model, ",")
            model = Ops.get_string(card_l, 0, model)
          end
        end
        modname = get_module_by_cardname(longmodel)

        Sound.curr_vendor = vendor
        Sound.curr_driver = modname
        Sound.curr_model = model

        ret = { "ui" => :next, "module" => modname, "model" => model }
      end
      deep_copy(ret)
    end

    # just calls ManualDialog
    # @return [Hash] passed result from ManualDialog
    def sound_manual
      ManualDialog()
    end
  end
end
