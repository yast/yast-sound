# encoding: utf-8

# File:
#   routines.ycp
#
# Module:
#   Sound
#
# Summary:
#   Routines for sound card configuration
#
# Authors:
#   Dan Vesely <dan@suse.cz>
#   Dan Meszaros <dmeszar@suse.cz>
#
#
module Yast
  module SoundRoutinesInclude
    def initialize_sound_routines(include_target)
      Yast.import "UI"
      Yast.import "Directory"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Sound"
      Yast.import "Label"
      Yast.import "Arch"

      textdomain "sound"


      # list of all card models (generated only once and cached)
      @all_card_names = []

      # list of all sound modules (table items)
      @all_module_items = []
    end

    def detect_cdrom
      ret = []
      cdroms = Convert.convert(
        SCR.Read(path(".probe.cdrom")),
        :from => "any",
        :to   => "list <map>"
      )

      Builtins.foreach(cdroms) do |cd|
        ret = Builtins.add(
          ret,
          {
            "model"    => Ops.get_locale(
              cd,
              "model",
              _("Unknown CD-ROM device")
            ),
            "dev_name" => Ops.get_string(cd, "dev_name", "/dev/cdrom")
          }
        )
      end if cdroms != nil

      Builtins.y2milestone("Detected CD-ROM devices: %1", ret)

      deep_copy(ret)
    end

    def CDpopup(headline, question, cdroms)
      cdroms = deep_copy(cdroms)
      items = []

      Builtins.foreach(cdroms) do |cd|
        dev = Ops.get_string(cd, "dev_name", "/dev/cdrom")
        model = Ops.get_locale(cd, "model", _("Unknown CD-ROM Device"))
        items = Builtins.add(
          items,
          Item(Id(dev), Builtins.sformat("%1 (%2)", model, dev))
        )
      end 



      yes_button = PushButton(
        Id(:ok),
        Opt(:default, :key_F10),
        Label.ContinueButton
      )
      no_button = PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)

      button_box = HBox(
        HStretch(),
        HWeight(1, yes_button),
        HSpacing(2),
        HWeight(1, no_button),
        HStretch()
      )

      content = VBox(
        Heading(headline),
        VSpacing(0.2),
        Left(Label(question)),
        VSpacing(0.2),
        Left(ComboBox(Id(:device), _("CD-ROM &Device"), items)),
        VSpacing(0.2),
        button_box
      )

      UI.OpenDialog(Opt(:decorated), content)

      ret = UI.UserInput
      device = Convert.to_string(UI.QueryWidget(Id(:device), :Value))

      UI.CloseDialog

      { "ui" => ret, "dev_name" => device }
    end

    # Mount specified device
    # @param [String] device device name to mount
    # @return [String] mount point where device was mounted (in /tmp subdirectory)
    #         or nil when mount failed
    def mount_device(device)
      tmpdir = Convert.to_string(SCR.Read(path(".target.tmpdir")))
      mpoint = Ops.add(tmpdir, "/mount")

      # create mount point directory
      SCR.Execute(path(".target.mkdir"), mpoint)

      # mount device
      result = Convert.to_boolean(
        SCR.Execute(path(".target.mount"), [device, mpoint], "-o ro")
      )

      result == true ? mpoint : nil
    end

    def umount_device(mount_point)
      Convert.to_boolean(SCR.Execute(path(".target.umount"), mount_point))
    end

    # returns cards manufactured by given vendor (ALSA only) or driver
    # @param [String] key vendor or driver; if "all" returns all models
    # @param [String] keys in which set is the key: "vendors" or "modules"
    # @return [Array] with sound card models
    def get_card_names(key, keys)
      Sound.LoadDatabase(true)

      if key == "all" || key == ""
        if @all_card_names == [] || @all_card_names == nil
          # use card names from db_cards (they contain the vendor name)
          all_card_names_list = Builtins.maplist(
            Convert.convert(
              Sound.db_cards,
              :from => "map",
              :to   => "map <integer, list>"
            )
          ) { |k, v| v }
          @all_card_names = Builtins.sort(
            Convert.convert(
              Builtins.flatten(all_card_names_list),
              :from => "list",
              :to   => "list <string>"
            )
          )
        end
        return deep_copy(@all_card_names)
      end

      if keys == "vendors"
        # names from db_vendors (vendor name not included - not necessary)
        return Builtins.sort(Ops.get_list(Sound.db_vendors, key, []))
      else
        return [Builtins.sformat("Sound card (%1)", key)] if !Sound.use_alsa

        mods = Builtins.mapmap(
          Convert.convert(
            Sound.db_module_index,
            :from => "map",
            :to   => "map <integer, string>"
          )
        ) { |k, v| { v => k } }
        index = Ops.get_integer(mods, key, 0)
        cards = Builtins.sort(Ops.get_list(Sound.db_cards, index, []))

        if cards == []
          cards = [Ops.get_string(Sound.db_modules, [key, "description"], "")]
        end
        return deep_copy(cards)
      end
    end

    #  Returns list of already running cards
    #	(oss is nasty hacked, because it's not trivial to check this)
    #  @return [Array]
    def get_running_cards
      # return empty list in autoyast config mode
      return [] if Mode.config

      return [1, 2, 3, 4, 5] if !Sound.use_alsa

      proot = path(".audio.alsa.cards")
      cards = SCR.Dir(proot)
      Builtins.maplist(cards) do |c|
        {
          "number" => Builtins.tointeger(c),
          "name"   => SCR.Read(Builtins.add(Builtins.add(proot, c), "name"))
        }
      end
    end

    # returns the 'params' section from sndcards.yml of the given module
    # @param [String] modname module name
    # @return [Hash] with params and their descriptions
    def get_module_params(modname)
      if !Sound.use_alsa
        params = Convert.convert(
          SCR.Read(
            Builtins.topath(
              Builtins.sformat(".modinfo.kernel.drivers.sound.%1", modname)
            )
          ),
          :from => "any",
          :to   => "map <string, string>"
        )
        params = Builtins.filter(params) do |k, v|
          !Builtins.contains(
            ["module_author", "module_description", "module_filename"],
            k
          )
        end
        return Builtins.mapmap(params) do |name, desc|
          { name => { "name" => name, "descr" => [desc], "type" => "string" } }
        end
      end

      Sound.LoadDatabase(true)
      Ops.get_map(Sound.db_modules, [modname, "params"], {})
    end

    # adds alias to save_info entry
    # @param [Hash] entry card config
    # @param [Fixnum] card_id card id
    # @return [Hash] modified card entry with filled alias value
    def add_alias(entry, card_id)
      entry = deep_copy(entry)
      if !Sound.use_alsa
        return Builtins.add(
          entry,
          "alias",
          Builtins.sformat("sound-slot-%1", card_id)
        )
      else
        return Builtins.add(
          entry,
          "alias",
          Builtins.sformat("snd-card-%1", card_id)
        )
      end
    end

    #  adds common options for module. for alsa it is 'snd_index=${card_id}'
    #  @param [Hash] entry card config
    #  @param [Fixnum] card_id card id
    #  @return [Hash] modified save_entry
    def add_common_options(entry, card_id)
      entry = deep_copy(entry)
      Builtins.y2milestone(
        "add_common_options: card: %1, entry: %2",
        card_id,
        entry
      )

      opts = Ops.get_map(entry, "options", {})

      if !Sound.use_alsa
        parms = Convert.convert(
          get_module_params(Ops.get_string(entry, "module", "")),
          :from => "map",
          :to   => "map <string, any>"
        )
        if Builtins.size(parms) != 0
          enab = Builtins.filter(parms) { |name, e| name == "snd_enable" }
          if Builtins.size(enab) != 0
            opts = Builtins.add(opts, "snd_enable", "1")
          end
        end
        entry = Builtins.add(entry, "options", opts)
        return deep_copy(entry)
      end
      # check existence of 'common' parameters: 'index'
      modname = Ops.get_string(entry, "module", "")
      Builtins.foreach(
        Convert.convert(
          SCR.Read(
            Builtins.topath(
              Builtins.sformat(".modinfo.kernel.drivers.sound.%1", modname)
            )
          ),
          :from => "any",
          :to   => "map <string, string>"
        )
      ) do |key, value|
        Ops.set(opts, key, Builtins.sformat("%1", card_id)) if key == "index"
      end
      Ops.set(entry, "options", opts)
      deep_copy(entry)
    end

    # Simply returns list with ALSA OSS/Free emulation modules
    # @param [Fixnum] number number of sound cards
    # @return [Array] of oss-alsa aliases
    def alsa_oss(number)
      return [] if !Sound.use_alsa

      modules = []
      i = 0

      while Ops.less_than(i, number)
        modules = Builtins.add(
          modules,
          {
            "alias"  => Builtins.sformat("sound-slot-%1", i),
            "module" => Builtins.sformat("snd-card-%1", i)
          }
        )
        i = Ops.add(i, 1)
      end
      deep_copy(modules)
    end

    # returns list of all available sound modules (OSS only)
    # @return [Array] as above
    def get_module_names
      if @all_module_items == [] || @all_module_items == nil
        if Sound.use_alsa
          Sound.LoadDatabase(true)
          mods = Builtins.maplist(
            Convert.convert(
              Sound.db_modules,
              :from => "map",
              :to   => "map <string, map <string, any>>"
            )
          ) do |k, v|
            Item(
              Id(k),
              Builtins.sformat(
                _("%1 (%2)"),
                Ops.get_string(v, "description", k),
                k
              )
            )
          end

          mods = Builtins.sort(mods) do |a, b|
            Ops.less_than(Ops.get_string(a, 1, ""), Ops.get_string(b, 1, ""))
          end

          # item for all sound card models in sound card driver list
          mods = Builtins.prepend(mods, Item(Id("all"), _("All")))
          @all_module_items = deep_copy(mods)
        else
          ret = SCR.Dir(path(".modinfo.kernel.sound.oss"))
          ret = Builtins.filter(ret) { |mod| mod != "sound" }
          ret = Builtins.add(ret, "emu10k1")
          ret = Builtins.add(ret, "cs4281")
          ret_t = Builtins.maplist(ret) do |e|
            modinfo = Convert.to_map(
              SCR.Read(Builtins.add(path(".modinfo.kernel.sound.oss"), e))
            )
            descr = Ops.get_string(modinfo, "module_description", "")
            Item(Id(e), descr != "" && descr != "<none>" ? descr : e)
          end
          ret_t = Builtins.sort(ret_t) do |a, b|
            Ops.less_than(Ops.get_string(a, 1, ""), Ops.get_string(b, 1, ""))
          end
          @all_module_items = deep_copy(ret_t)
        end
      end
      deep_copy(@all_module_items)
    end

    #  * get_vol_settings
    #  * creates a list of stored values of volume and mute for each channel
    #  * of each card.
    #  * example: [
    # 		    [ ["PCM", 32, false], ["Master", 100, true]],
    # 		    [ [....], .....                            ]
    # 		]
    #  * @return list as above
    def get_vol_settings
      return [] if !Sound.use_alsa

      Sound.LoadDatabase(true)
      bound = Builtins.size(SCR.Dir(path(".audio.alsa.cards")))
      i = 0
      retlist = []
      while Ops.less_than(i, bound)
        volumelist = []
        modname = Ops.get_string(Sound.modules_conf, [i, "module"], "snd-dummy")
        chans = Ops.get_list(Sound.db_modules, [modname, "mixer_elements"], [])

        if chans == []
          if Builtins.contains(
              SCR.Dir(path(".audio.alsa.cards")),
              Builtins.sformat("%1", i)
            )
            chans = SCR.Dir(
              Builtins.topath(
                Builtins.sformat(".audio.alsa.cards.%1.channels", i)
              )
            )
          else
            chans = []
          end
        end

        Builtins.foreach(chans) do |e|
          pth1 = Builtins.topath(
            Builtins.sformat(".audio.alsa.cards.%1.channels.%2.volume", i, e)
          )
          pth2 = Builtins.topath(
            Builtins.sformat(".audio.alsa.cards.%1.channels.%2.mute", i, e)
          )
          volumelist = Builtins.add(
            volumelist,
            [e, SCR.Read(pth1), SCR.Read(pth2)]
          )
        end
        retlist = Builtins.add(retlist, volumelist)

        i = Ops.add(i, 1)
      end
      deep_copy(retlist)
    end

    # stores values generated by get_vol_settings
    # @param [Array] vol_settings volume settings
    # @return [Boolean] success/failure
    def set_vol_settings(vol_settings)
      vol_settings = deep_copy(vol_settings)
      return true if !Sound.use_alsa

      # during autoinstallation, vol_settings list looks different... :-(
      vol_settings = Builtins.maplist(vol_settings) do |it|
        if it == nil
          next {}
        else
          next deep_copy(it)
        end
      end if Mode.autoinst(
      )

      if Ops.is(vol_settings, "list <list <map>>")
        Builtins.y2milestone("AutoYast data detected, converting...")
        # convert
        # 		[
        # 		    [ $["mute":false, "name":"Master", "volume":96], ... ]
        # 		    [ ... ]
        # 		]
        #  to
        # 		[
        # 		    [ ["PCM", 32, false], ["Master", 100, true]],
        # 		    [ [....], .....                            ]
        # 		]

        cnv_vol_settings = Builtins.maplist(
          Convert.convert(
            vol_settings,
            :from => "list",
            :to   => "list <list <map>>"
          )
        ) { |card_setting| Builtins.maplist(card_setting) do |channel_config|
          [
            Ops.get_string(channel_config, "name", ""),
            Ops.get_integer(channel_config, "volume", 0),
            Ops.get_boolean(channel_config, "mute", true)
          ]
        end }

        Builtins.y2milestone(
          "Volume settings converted: %1 -> %2",
          vol_settings,
          cnv_vol_settings
        )

        vol_settings = deep_copy(cnv_vol_settings)
      end

      item = Ops.get(vol_settings, 0)
      if Ops.is_map?(item)
        vol_settings = Builtins.maplist(
          Convert.convert(vol_settings, :from => "list", :to => "list <map>")
        ) { |onecard| Builtins.maplist(onecard) do |ch, vol|
          [ch, vol]
        end }
      end
      i = 0

      Builtins.foreach(
        Convert.convert(
          vol_settings,
          :from => "list",
          :to   => "list <list <list>>"
        )
      ) do |channels|
        Builtins.foreach(channels) do |channel|
          name = Ops.get_string(channel, 0, "Master")
          pth1 = Builtins.topath(
            Builtins.sformat(".audio.alsa.cards.%1.channels.%2.volume", i, name)
          )
          pth2 = Builtins.topath(
            Builtins.sformat(".audio.alsa.cards.%1.channels.%2.mute", i, name)
          )
          SCR.Write(pth1, Ops.get_integer(channel, 1, 0))
          SCR.Write(pth2, Ops.get_boolean(channel, 2, false))
        end
        i = Ops.add(i, 1)
      end
      SCR.Execute(path(".audio.alsa.store"), "")
      true
    end


    # common function to extract 'name' of hardware
    # @param [Hash] hardware_entry map
    # @return [String] readable name of the card
    def hardware_name(hardware_entry)
      hardware_entry = deep_copy(hardware_entry)
      Builtins.y2debug("hardware_entry: %1", hardware_entry)

      sub_vendor = Ops.get_string(hardware_entry, "sub_vendor", "")
      sub_device = Ops.get_string(hardware_entry, "sub_device", "")
      vendor = Ops.get_string(hardware_entry, "vendor", "")
      device = Ops.get_string(hardware_entry, "device", "")

      if sub_vendor != "" && sub_device != ""
        return Ops.add(Ops.add(sub_vendor, "\n"), sub_device)
      elsif vendor == "" && device == ""
        model = Ops.get_string(hardware_entry, "model", "")
        module_desc = Ops.get_string(
          hardware_entry,
          ["module", "description"],
          ""
        )

        return Ops.add(
          Ops.greater_than(Builtins.size(model), 0) &&
            Ops.greater_than(Builtins.size(module_desc), 0) ?
            Ops.add(Ops.add(model, " - "), module_desc) :
            model,
          module_desc
        )
      else
        return Ops.add(Ops.add(vendor, vendor != "" ? "\n" : ""), device)
      end
    end


    # filters out already configured cards
    # @param [Array<Hash>] save_info info from modules.conf
    # @param [Array<Hash>] cards autodetected cards
    # @return [Array] of entries of not configured cards
    def filter_configured(save_info, cards)
      save_info = deep_copy(save_info)
      cards = deep_copy(cards)
      Builtins.filter(cards) do |det_card|
        uniq = Ops.get_string(det_card, "unique_key", "")
        retval = true
        Builtins.foreach(save_info) do |saved_card|
          retval = false if Ops.get_string(saved_card, "unique_key", "") == uniq
        end
        retval
      end
    end

    # for a given card detected by libhd this function creates a label
    # @param [Hash] card map entry from .probe.audio
    # @return [String] card label
    def get_card_label(card)
      card = deep_copy(card)
      lab = Builtins.splitstring(hardware_name(card), "\n")

      Builtins.y2debug("Card label: %1", lab)

      return "" if Builtins.size(lab) == 0
      if Builtins.size(lab) == 1 || Ops.get_string(lab, 1, "") == ""
        return Ops.get_string(lab, 0, "")
      end
      Ops.get_string(lab, 1, "")
    end

    # returns true if given string is valid sound alias
    # (snd-card-1 .. snd-card-16)
    # @param [String] alias string
    # @return [Boolean] is/is not
    def is_snd_alias(_alias)
      if Sound.use_alsa
        return Builtins.regexpmatch(_alias, "^snd-card-[0-9]*$")
      else
        return Builtins.regexpmatch(_alias, "^sound-slot-[0-9]*$")
      end
    end

    # unique key for non-pci/pnp cards or virtual cards
    # @return [String] key for legacy isa cards
    def isa_uniq
      "uniq.unknown_key"
    end

    # reads variables listed in 'vars' from rc.config
    # @return [Hash] optname: value
    def read_rc_vars
      { "LOAD_ALSA_SEQ" => SCR.Read(path(".sysconfig.sound.LOAD_SEQUENCER")) }
    end

    # saves uniq keys to .probe.status
    # @param [Array] configured list of strings of configured cards uniq keys
    # @param [Array] unconfigured list of string of unconfigured cards uniq keys
    # @return [Boolean] true
    def SaveUniqueKeys(configured, unconfigured)
      configured = deep_copy(configured)
      unconfigured = deep_copy(unconfigured)
      Builtins.maplist(
        Convert.convert(configured, :from => "list", :to => "list <string>")
      ) { |uk| SCR.Write(path(".probe.status.configured"), uk, :yes) }

      Builtins.maplist(
        Convert.convert(unconfigured, :from => "list", :to => "list <string>")
      ) { |uk| SCR.Write(path(".probe.status.configured"), uk, :no) }

      true
    end



    # Used for searching. returns index of the card in the database
    # identified by name (more exactly: returns index of first name matching
    # the given substring)
    # @param [String] name card name (or its substring)
    # @return [Fixnum] position of the card
    def search_card_id(name)
      all_cards = get_card_names("all", "vendors")
      pos = 0
      len = Builtins.size(name)
      name = Builtins.tolower(name)
      bound = Builtins.size(all_cards)
      while Ops.less_than(pos, bound)
        if Builtins.substring(
            Builtins.tolower(Ops.get_string(all_cards, pos, "")),
            0,
            len
          ) == name
          return pos
        end
        pos = Ops.add(pos, 1)
      end
      -1
    end

    # Itemize list for selection box
    # @param [Array] l list with values
    # @param [Fixnum] default_value value to select as default
    # @return [Array] items to be shown in list widget
    def itemize_list(l, default_value)
      l = deep_copy(l)
      i = 0
      itemized_list = []
      s = Builtins.size(l)
      while Ops.less_than(i, s)
        itemized_list = Builtins.add(
          itemized_list,
          Item(Id(i), Ops.get_string(l, i, ""), i == default_value)
        )
        i = Ops.add(i, 1)
      end
      deep_copy(itemized_list)
    end


    #	show a warning popup for nm256 snd cards if needed
    #  @param [String] modname string module name
    #  @return [Boolean] continue/abort

    def nm256hack(modname)
      if modname == "snd-nm256"
        # special warning message for in a special case
        warn_text = Ops.get_string(Sound.STRINGS, "nm256hackWarning", "")
        return Popup.YesNo(warn_text)
      end
      true
    end

    def layout_id
      ret = false

      if Arch.board_mac
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            "/usr/bin/find /proc/device-tree -name layout-id"
          )
        )

        if Ops.get_integer(out, "exit", -1) == 0 &&
            Ops.greater_than(
              Builtins.size(Ops.get_string(out, "stdout", "")),
              0
            )
          Builtins.y2milestone(
            "Layout-id property detected: %1",
            Ops.get_string(out, "stdout", "")
          )
          ret = true
        end
      end

      ret
    end

    # Looks up in the database for the module
    # @param [Hash] card map read from .probe.sound
    # @return [Hash] relevant card info found in db
    def get_module(card)
      card = deep_copy(card)
      Sound.LoadDatabase(true)

      bus = Ops.get_string(card, "bus", "")
      offset = Builtins.tolower(bus) == "isa" ? 131072 : 65536
      vendor_id = Ops.subtract(Ops.get_integer(card, "vendor_id", 0), offset)
      device_id = Ops.subtract(Ops.get_integer(card, "device_id", 0), offset)

      m1 = Ops.get_map(Sound.db_indices, vendor_id, {})
      Builtins.y2warning("vendor_id (%1) not found...", vendor_id) if m1 == {}

      m2 = Ops.get_integer(m1, device_id, -1)
      Builtins.y2warning("device_id (%1) not found", device_id) if m2 == -1

      modname = ""

      if Builtins.haskey(Sound.db_module_index, m2)
        modname = Ops.get_string(Sound.db_module_index, m2, "")
      else
        Builtins.y2warning("Missing driver name in DB for card: %1", card)
        # driver for the sound card is not known
        # use value from hwinfo if present
        modname = Ops.get_string(card, ["drivers", 0, "modules", 0, 0], "")

        # convert module name - hwinfo might use _ in module name prefix (e.g. snd_via82xx)
        modname = Builtins.mergestring(Builtins.splitstring(modname, "_"), "-")

        if modname != ""
          Builtins.y2warning("Using driver provided by hwinfo: %1", modname)
        else
          Builtins.y2internal("Module for the card is unknown") 
          # TODO: manual configuration is needed
        end
      end


      # ppc hack - use snd-aoa instead of snd-powermac (#217300)
      if modname == "snd-powermac" && layout_id
        Builtins.y2milestone(
          "Card '%1': Using snd-aoa driver instead of snd-powermac",
          Ops.get_string(card, "model", "")
        )
        modname = "snd-aoa"
      end

      ret = Ops.get_map(Sound.db_modules, modname, {})

      if !Builtins.haskey(ret, "name")
        # we must supply the 'name' key with the module name
        ret = Builtins.add(ret, "name", modname)
      end

      Builtins.y2milestone(
        "card: '%1', using module %2",
        Ops.get_string(card, "model", ""),
        modname
      )

      deep_copy(ret)
    end

    # umnute channel 'devide' of the 'card_id'-th sound card. alsa only
    # @param [Array] devices list of channels to be unmuted
    # @param [Fixnum] card_id of the card
    # @return [void]
    def unmute(devices, card_id)
      devices = deep_copy(devices)
      return if Mode.config

      avail = SCR.Dir(
        Builtins.topath(
          Builtins.sformat(".audio.alsa.cards.%1.channels", card_id)
        )
      )
      avail = [] if avail == nil || Builtins.size(avail) == 0
      Builtins.foreach(
        Convert.convert(devices, :from => "list", :to => "list <string>")
      ) do |dev|
        if Builtins.contains(avail, dev)
          SCR.Write(
            Builtins.topath(
              Builtins.sformat(
                ".audio.alsa.cards.%1.channels.%2.mute",
                card_id,
                dev
              )
            ),
            false
          )
        end
      end

      nil
    end


    # Checks whether the module has been successfully loaded
    #
    # @param [Hash] save_entry card config map
    # @param [Fixnum] card_id card id
    # @return [String] empty on success/ error message on failure
    def check_module(save_entry, card_id)
      save_entry = deep_copy(save_entry)
      pm = Convert.to_map(SCR.Read(path(".proc.modules")))
      modname = Ops.get_string(save_entry, "module", "off")
      l = Builtins.splitstring(modname, "-")
      mod_name = Builtins.mergestring(l, "_")

      if !Builtins.haskey(pm, modname) && !Builtins.haskey(pm, mod_name) ||
          Ops.less_or_equal(Builtins.size(get_running_cards), card_id)
        # add debug info to the y2log
        Builtins.y2milestone("modules: %1", pm)
        Builtins.y2milestone("modname: %1", modname)
        Builtins.y2milestone("mod_name: %1", mod_name)
        Builtins.y2milestone("get_running_cards: %1", get_running_cards)
        Builtins.y2milestone("card_id: %1", card_id)
        Builtins.y2milestone(
          "/proc cards: %1",
          SCR.Read(path(".target.string"), "/proc/asound/cards")
        )

        # label to error popup, %1 is module name
        return Builtins.sformat(
          _(
            "The kernel module %1 for sound support\n" +
              "could not be loaded. This can be caused by incorrect\n" +
              "module parameters, including invalid IO or IRQ parameters."
          ),
          modname
        )
      end
      ""
    end

    # inserts values to already set options
    # @param [Hash] params list with available options for module
    # @param [Hash] values values that have been already set
    # @return [Hash] with refreshed options
    #
    def restore_mod_params(params, values)
      params = deep_copy(params)
      values = deep_copy(values)
      ret = Builtins.mapmap(
        Convert.convert(
          params,
          :from => "map",
          :to   => "map <string, map <string, any>>"
        )
      ) do |parname, parmap|
        parmap = Builtins.add(
          parmap,
          "value",
          Ops.get_string(values, parname, "")
        )
        { parname => parmap }
      end


      ignore_options = ["index", "enable"]
      # add option from values map which are not contained in parms map
      Builtins.foreach(
        Convert.convert(values, :from => "map", :to => "map <string, string>")
      ) do |key, value|
        if !Builtins.haskey(params, key) &&
            !Builtins.contains(ignore_options, key)
          ret = Builtins.add(ret, key, { "value" => value })
          Builtins.y2milestone("Added extra option: %1='%2'", key, value)
        end
      end 


      Builtins.y2milestone("ret: %1", ret)
      deep_copy(ret)
    end

    #  checks whether SoundFonts have already been installed
    #	@return [Boolean] already installed/not installed
    #

    def FontsInstalled
      Ops.greater_or_equal(
        SCR.Read(path(".target.size"), "/usr/share/sfbank/creative"),
        0
      )
    end

    # return true if the sound card supports SoundFonts
    # @param [Hash] save_entry save entry
    # @return [Boolean]	card supports fonts/it doesn't

    def HasFonts(save_entry)
      save_entry = deep_copy(save_entry)
      if Mode.config
        # don't install SoundFonts during autoinstallation config
        return false
      end

      if Builtins.contains(
          ["snd-emu10k1", "snd-sbawe", "emu10k1"],
          Ops.get_string(save_entry, "module", "")
        )
        return true
      end
      false
    end

    #  this small wizard will install SoundFonts for soundblaster live/awe
    #  @param [String] symlink is path to default.sf2 that is to be created
    #  @param [Boolean] dontask if true, skip the first messagebox
    #  @return [void]

    def InstallFonts(symlink, dontask)
      answer = false

      # step 1: want install?
      if dontask
        answer = true
      else
        answer = Popup.YesNoHeadline(
          Ops.get_string(Sound.STRINGS, "soundFontTitle", ""),
          Ops.get_string(Sound.STRINGS, "soundFontQuestion", "")
        )
      end

      return if !answer

      while true
        detected_cds = detect_cdrom
        cdrom_device = ""

        if Builtins.size(detected_cds) == 0
          # no CD device present, exit
          return
        # one CD device present, use it
        elsif Builtins.size(detected_cds) == 1
          # step 2: insert CD
          if !Popup.ContinueCancelHeadline(
              Ops.get_string(Sound.STRINGS, "soundFontTitle", ""),
              Ops.get_string(Sound.STRINGS, "soundFontAppeal", "")
            )
            return
          end

          cdrom_device = Ops.get_string(
            detected_cds,
            [0, "dev_name"],
            "/dev/cdrom"
          )
        else
          # step 2: ask for a CD device

          ui = CDpopup(
            Ops.get_string(Sound.STRINGS, "soundFontTitle", ""),
            Ops.get_string(Sound.STRINGS, "soundFontAppeal", ""),
            detected_cds
          )

          return if Ops.get_symbol(ui, "ui", :unknown) != :ok

          cdrom_device = Ops.get_string(ui, "dev_name", "/dev/cdrom")
        end

        Builtins.y2milestone("Using cdrom device: %1", cdrom_device)

        mpoint = mount_device(cdrom_device)
        Builtins.y2milestone("Device mounted: %1", mpoint)

        # number of found SoundFont files
        cnt = 0
        if mpoint != nil
          # step3: do something
          res = Convert.to_map(
            SCR.Execute(
              path(".target.bash_output"),
              Ops.add(Ops.add(Directory.ybindir, "/copyfonts "), mpoint),
              {}
            )
          )

          Builtins.y2milestone("copyfonts output: %1", res)
          cnt = Builtins.tointeger(Ops.get_string(res, "stdout", "0"))

          Builtins.y2milestone("Device unmounted: %1", umount_device(mpoint))

          # restart ALSA after SoundFont copy
          cmd = Ops.add(Directory.bindir, "/alsadrivers reload")
          Builtins.y2milestone("Executing: %1", cmd)
          SCR.Execute(path(".target.bash"), cmd)
        end

        # step4:
        if Ops.greater_than(cnt, 0)
          Popup.Message(
            Builtins.sformat(
              Ops.get_string(Sound.STRINGS, "soundFontFinal", ""),
              cnt,
              "/usr/share/sfbank/creative"
            )
          )
          return
        else
          if !Popup.YesNoHeadline(
              Ops.get_string(Sound.STRINGS, "soundFontNotFound", ""),
              Ops.get_string(Sound.STRINGS, "soundFontRetry", "")
            )
            return
          end
        end
      end

      nil
    end

    # does this machine need a nm256/opl3sa warning?
    # @param [Array] sound_cards sound cards
    # @return [Boolean] see as above
    def need_nm256_opl3sa2_warn(sound_cards)
      sound_cards = deep_copy(sound_cards)
      mods = Builtins.maplist(
        Convert.convert(
          sound_cards,
          :from => "list",
          :to   => "list <map <string, any>>"
        )
      ) { |card| Ops.get_string(card, "module", "") }
      if Builtins.contains(mods, "snd-nm256") &&
          Builtins.contains(mods, "snd-opl3sa2")
        return true
      end
      false
    end

    # shows warning message when both nm265 and opl3sa2 cards are present
    # @param [Array] sound_cards list of sound cards
    # @return [void]
    def nm256_opl3sa2_warn(sound_cards)
      sound_cards = deep_copy(sound_cards)
      s1 = Builtins.filter(
        Convert.convert(
          sound_cards,
          :from => "list",
          :to   => "list <map <string, any>>"
        )
      ) { |e| Ops.get_string(e, "module", "") == "snd-nm256" }
      s2 = Builtins.filter(
        Convert.convert(
          sound_cards,
          :from => "list",
          :to   => "list <map <string, any>>"
        )
      ) { |e| Ops.get_string(e, "module", "") == "snd-opl3sa2" }

      if Ops.greater_than(Builtins.size(s1), 0) &&
          Ops.greater_than(Builtins.size(s2), 0)
        name1 = Ops.get_string(s1, [0, "model"], "")
        name2 = Ops.get_string(s2, [0, "model"], "")
        Popup.LongText(
          "",
          RichText(
            Ops.add(
              Ops.add(
                "<p>",
                Builtins.sformat(
                  Ops.get_string(Sound.STRINGS, "opl3sa_nm256_warn", ""),
                  name1,
                  name2
                )
              ),
              "</p>"
            )
          ),
          50,
          12
        )
      end

      nil
    end

    # Hack for Thinkpad 600E notebook - it need cs4236 module instead of cs4610
    # @param [Fixnum] card_id card number
    def Thinkpad600E_cs4236_hack(card_id)
      card = deep_copy(Sound.save_entry)
      modname = "snd-cs4236"

      Builtins.foreach(Sound.detected_cards) do |c|
        if Ops.get_string(c, "unique_key", "") ==
            Ops.get_string(card, "unique_key", "")
          # 1. is it right card? -> check subsystem + subvendor id
          if Ops.get_integer(c, "sub_device_id", 0) == 69648 &&
              Ops.get_integer(c, "sub_vendor_id", 0) == 69652 &&
              Ops.get_string(card, "module", "") != modname
            # popup question: different module has to be choosed
            if !Popup.YesNo(
                _(
                  "It seems that you have a Thinkpad 600E laptop.\n" +
                    "On this laptop, the CS4236 driver should be used\n" +
                    "although the CS46xx chip is detected.\n" +
                    "Attempt to probe the configuration of CS4236 driver?\n" +
                    "\n" +
                    "Warning: The probe procedure can take some time and\n" +
                    "could make your system unstable.\n"
                )
              )
              next
            end

            ret = Sound.ProbeOldChip("cs4236")
            if ret != ""
              returned = Builtins.splitstring(ret, "\n")
              ret = Ops.get_string(returned, 0, "")

              options = {}
              Builtins.foreach(Builtins.splitstring(ret, " ")) do |o|
                op = Builtins.splitstring(o, "=")
                if Builtins.size(op) == 2
                  options = Builtins.add(
                    options,
                    Ops.get_string(op, 0, ""),
                    Ops.get_string(op, 1, "")
                  )
                end
              end
              Ops.set(card, "options", options)
              Ops.set(card, "module", modname)
              Sound.save_entry = Builtins.eval(card) 
              # TODO save the card to unconfigured cards???
            end
          end
        end
      end

      nil
    end


    # removes entries from save_info listed by indices in id_list
    # @param [Array<Hash>] save_info list
    # @return [Array] new save_info
    def recalc_save_entries(save_info)
      save_info = deep_copy(save_info)
      pos = 0
      Builtins.maplist(save_info) do |card|
        opts = Ops.get_map(card, "options", {})
        card = add_alias(card, pos)
        card = add_common_options(card, pos)
        pos = Ops.add(pos, 1)
        deep_copy(card)
      end
    end
  end
end
