# encoding: utf-8

# File:
#   read_routines.ycp
#
# Module:
#   Sound
#
# Summary:
#   Routines for reading sound card configuration
#
# Authors:
#   Dan Meszaros <dmeszar@suse.cz>
#
module Yast
  module SoundReadRoutinesInclude
    def initialize_sound_read_routines(include_target)
      Yast.import "UI"
      Yast.import "Sound"
      Yast.import "HWConfig"
      Yast.import "Confirm"
      Yast.import "String"

      Yast.include include_target, "sound/routines.rb"

      textdomain "sound"
    end

    # tries to determine card model name from audio.alsa agent
    # @param [Fixnum] card_id card id
    # @return card name, "Sound card" on failure
    def read_card_name_from_alsa(card_id)
      pth = Builtins.topath(
        Builtins.sformat(".audio.alsa.cards.%1.name", card_id)
      )
      name = Convert.to_string(SCR.Read(pth))
      return "Sound card" if name == nil
      name
    end


    # Extacts the unique key and the name of the card from comment in the
    # modules.conf placed before char-major-81-x
    # @param [String] comment before the char-major-81-x
    # @return [Hash] example: $[ "unique_key" : string, "name" : string ] or nil
    def extractUniqueKey(comment)
      result = nil

      # split to lines
      comment_lines = Builtins.splitstring(comment, "\n")

      # find last line with a ":"
      line_with_uk = ""
      colon_pos_uk = nil
      Builtins.foreach(comment_lines) do |line|
        c_pos = Builtins.findfirstof(line, ":")
        if c_pos != nil
          line_with_uk = line
          colon_pos_uk = c_pos
        end
      end

      # did we find it?
      if colon_pos_uk != nil
        # extract name
        name = Builtins.substring(
          line_with_uk,
          Ops.add(colon_pos_uk, 1),
          Ops.subtract(
            Ops.subtract(Builtins.size(line_with_uk), colon_pos_uk),
            1
          )
        )
        # extract unique key
        start_uk = Builtins.findfirstnotof(line_with_uk, "# \t")
        uk = Builtins.substring(
          line_with_uk,
          start_uk,
          Ops.subtract(colon_pos_uk, start_uk)
        )

        result = { "name" => name, "unique_key" => uk }
      end
      deep_copy(result)
    end

    # sort module aliases according to snd slots option
    def sort_aliases(config_path, alias_path, aliases)
      aliases = deep_copy(aliases)
      # read 'snd' options
      snd_opts = Convert.convert(
        SCR.Read(Builtins.add(config_path, "snd")),
        :from => "any",
        :to   => "map <string, string>"
      )
      Builtins.y2milestone("snd optionss: %1", snd_opts)

      slots_option = Builtins.splitstring(Ops.get(snd_opts, "slots", ""), ",")
      slots_option = Builtins.maplist(slots_option) do |slotopt|
        String.CutBlanks(slotopt)
      end

      # alias -> driver mapping
      alias_mapping = {}

      # read aliases
      Builtins.foreach(aliases) do |a|
        Builtins.y2milestone("Reading alias %1", a)
        modname = Convert.to_string(SCR.Read(Builtins.add(alias_path, a)))
        alias_mapping = Builtins.add(alias_mapping, a, modname)
      end 


      # driver -> [ aliases ]
      driver_mapping = {}

      # create a reverse mapping
      Builtins.foreach(alias_mapping) do |_alias, driver|
        a_list = Ops.get(driver_mapping, driver, [])
        a_list = Builtins.add(a_list, _alias)
        Ops.set(driver_mapping, driver, a_list)
      end 


      Builtins.y2milestone("Driver mapping: %1", driver_mapping)

      sorted_aliases = []

      # sort aliases
      Builtins.foreach(slots_option) do |slot|
        aliases2 = Ops.get(driver_mapping, slot, [])
        sorted_aliases = Builtins.add(sorted_aliases, Ops.get(aliases2, 0, ""))
        aliases2 = Builtins.remove(aliases2, 0)
        Ops.set(driver_mapping, slot, aliases2)
      end 


      deep_copy(sorted_aliases)
    end


    # reads already saved info from given file
    # @return [Array]
    def read_modprobe(mod_path)
      save = [] # structure to save

      # path mod_path	= .modprobe_sound;
      #
      # // read from /etc/modprobe/conf if /etc/modprobe.d/50-sound.conf is not present
      # if (SCR::Read(.target.size, "/etc/modprobe.d/50-sound.conf") == -1)
      # {
      #     mod_path			= .modules;
      #     Sound::used_modprobe_conf	= true;
      # }

      mod_alias = Builtins.add(mod_path, "alias")
      mod_options = Builtins.add(mod_path, "options")

      aliases = Convert.convert(
        SCR.Read(mod_alias),
        :from => "any",
        :to   => "list <string>"
      )

      aliases = Builtins.filter(aliases) { |a| is_snd_alias(a) }

      # since parameters in modules options are separated by comas
      # (eg. options mod snd_id=1,2,3, snd_index=1,2,3),
      # we have to count occurences for each module
      position = -1
      mod_occur = {} # alsa modules

      det_cards = []

      # Confirmation: label text (detecting hardware: xxx)
      if !Confirm.Detection(_("Sound Cards"), nil)
        det_cards = []
        Sound.skip_detection = true
      else
        det_cards = Convert.convert(
          SCR.Read(path(".probe.sound")),
          :from => "any",
          :to   => "list <map>"
        )
      end

      Builtins.y2milestone("Detected cards: %1", det_cards)

      # sort the aliases according to the slots option
      aliases = sort_aliases(mod_options, mod_alias, aliases)

      Builtins.y2milestone("Sorted aliases acording to slots: %1", aliases)

      Builtins.foreach(aliases) do |a|
        Builtins.y2milestone("Reading alias %1", a)
        position = Ops.add(position, 1)
        modname = Convert.to_string(SCR.Read(Builtins.add(mod_alias, a)))
        opt_pos = Ops.get_integer(mod_occur, modname, 0)
        mod_occur = Builtins.add(
          mod_occur,
          modname,
          Ops.add(Ops.get_integer(mod_occur, modname, 0), 1)
        )
        opts = Convert.convert(
          SCR.Read(Builtins.add(mod_options, modname)),
          :from => "any",
          :to   => "map <string, string>"
        )
        options = {}
        Builtins.foreach(opts) do |name, val|
          vals = Builtins.splitstring(val, ",")
          if Ops.greater_than(Builtins.size(val), opt_pos)
            options = Builtins.add(
              options,
              name,
              Ops.get_string(vals, opt_pos, "")
            )
          end
        end
        # read card info from the comment string
        comment = Convert.to_string(
          SCR.Read(Builtins.add(Builtins.add(mod_alias, a), "comment"))
        )
        uniq = ""
        model = ""
        res = extractUniqueKey(comment)
        if res != nil
          uniq = Ops.get_string(res, "unique_key", "")
          model = Ops.get_string(res, "name", "")
        else
          # probably system upgrade
          uniq = isa_uniq
          model = read_card_name_from_alsa(position)
        end
        # add index option
        Ops.set(options, "index", Builtins.tostring(position))
        entry = {
          "alias"      => a,
          "module"     => modname,
          "options"    => options,
          "unique_key" => uniq,
          "model"      => model
        }
        Builtins.foreach(det_cards) do |dcard|
          if Ops.get_string(dcard, "unique_key", "") == uniq
            Builtins.y2debug("Found uniq %1: %2", uniq, dcard)
            if Builtins.haskey(dcard, "bus_hwcfg") &&
                Builtins.haskey(dcard, "sysfs_bus_id")
              Ops.set(entry, "bus", Ops.get_string(dcard, "bus_hwcfg", ""))
              Ops.set(
                entry,
                "bus_id",
                Ops.get_string(dcard, "sysfs_bus_id", "")
              )
              Ops.set(
                entry,
                "vendor_id",
                Ops.get_integer(dcard, "vendor_id", 0)
              )
              Ops.set(
                entry,
                "sub_vendor_id",
                Ops.get_integer(dcard, "sub_vendor_id", 0)
              )
              Ops.set(
                entry,
                "device_id",
                Ops.get_integer(dcard, "device_id", 0)
              )
              Ops.set(
                entry,
                "sub_device_id",
                Ops.get_integer(dcard, "sub_device_id", 0)
              )
            end
          end
        end
        Builtins.y2debug("entry: %1", entry)
        save = Builtins.add(save, entry)
      end
      deep_copy(save)
    end

    # reads already saved info from modules.conf
    # @example of return value:
    # [
    #	    $[
    #		"alias":    "snd-card-0",
    #		"module":   "snd-card-emu10k1",
    #		"options":  ["snd_id":"0", "snd_index":"card1"],
    #		"unique_key":"asdf.asdfasdfasdf",
    #		"model":    "Sound Blaster Live!"
    #	    ],
    #	    $[...]
    #	]
    # @return [Array]
    def read_save_info
      saved = []

      # First, read from /etc/modprobe.d/50-sound.conf
      if Ops.greater_or_equal(
          SCR.Read(path(".target.size"), "/etc/modprobe.d/50-sound.conf"),
          0
        )
        saved = read_modprobe(path(".modprobe_sound"))
      else
        Builtins.y2milestone("/etc/modprobe.d/50-sound.conf doesn't exist")

        # try /etc/modprobe.conf...
        if Ops.greater_or_equal(
            SCR.Read(path(".target.size"), "/etc/modprobe.conf"),
            0
          )
          saved = read_modprobe(path(".modules"))

          Sound.used_modprobe_conf = true if saved != []
        else
          Builtins.y2milestone("/etc/modprobe.conf doesn't exist")
        end
      end

      deep_copy(saved)
    end

    def read_hwconfig
      ret = []

      # get list of all config files
      cfiles = HWConfig.ConfigFiles

      # read module options
      mod_opts = read_save_info
      Builtins.y2milestone("mod_opts: %1", mod_opts)

      cardopts = {}
      ids = {}
      Builtins.foreach(mod_opts) do |op|
        Ops.set(
          cardopts,
          Ops.get_string(op, "alias", ""),
          Ops.get_map(op, "options", {})
        )
        idmap = {}
        if Ops.get_integer(op, "vendor_id", 0) != 0 &&
            Ops.get_integer(op, "device_id", 0) != 0
          Ops.set(idmap, "vendor_id", Ops.get_integer(op, "vendor_id", 0))
          Ops.set(idmap, "device_id", Ops.get_integer(op, "device_id", 0))
        end
        if Ops.get_integer(op, "sub_vendor_id", 0) != 0 &&
            Ops.get_integer(op, "sub_device_id", 0) != 0
          Ops.set(
            idmap,
            "sub_vendor_id",
            Ops.get_integer(op, "sub_vendor_id", 0)
          )
          Ops.set(
            idmap,
            "sub_device_id",
            Ops.get_integer(op, "sub_device_id", 0)
          )
        end
        if Ops.get_string(op, "bus", "") != ""
          Ops.set(idmap, "bus", Ops.get_string(op, "bus", ""))
        end
        Ops.set(ids, Ops.get_string(op, "unique_key", ""), idmap)
      end 


      Builtins.y2milestone("read module options: %1", cardopts)
      Builtins.y2milestone("read IDs: %1", ids)

      # scan each config file - search for sound card config
      Builtins.foreach(cfiles) do |cfile|
        com = HWConfig.GetComment(cfile, "MODULE")
        if com != nil
          coms = Builtins.splitstring(com, "\n")
          sound_card_found = false
          entry = {}

          Builtins.foreach(coms) do |comline|
            if Builtins.regexpmatch(
                comline,
                "^# YaST configured sound card snd-card-[0-9]*"
              )
              _alias = Builtins.regexpsub(
                comline,
                "^# YaST configured sound card (snd-card-[0-9]*)",
                "\\1"
              )

              if _alias != nil
                Ops.set(entry, "hwcfg", cfile)
                Ops.set(entry, "alias", _alias)

                # if the file uses the old config then force update
                if Builtins.regexpmatch(cfile, "^bus-pci-")
                  Builtins.y2milestone(
                    "detected old configuration file (%1), forced update of the configuration",
                    cfile
                  )
                  Sound.SetModified
                end

                opts = Ops.get(cardopts, _alias, {})

                if Ops.greater_than(Builtins.size(opts), 0)
                  Ops.set(entry, "options", opts)
                end

                sound_card_found = true
              end
            elsif Builtins.regexpmatch(comline, "^# ....\\............:.*")
              uniq = Builtins.regexpsub(
                comline,
                "^# (....\\............):(.*)",
                "\\1"
              )
              name = Builtins.regexpsub(
                comline,
                "^# (....\\............):(.*)",
                "\\2"
              )

              if uniq != nil
                Ops.set(entry, "unique_key", uniq)

                # add vendor/device ID
                idmap = Ops.get_map(ids, uniq, {})
                entry = Builtins.union(entry, idmap)
              end

              if name != nil
                Ops.set(entry, "model", name)
              else
                Ops.set(entry, "model", _("Unknown"))
              end
            end
          end 


          m = HWConfig.GetValue(cfile, "MODULE")
          Ops.set(entry, "module", m) if m != nil

          # TODO add bus ID

          if sound_card_found
            Builtins.y2milestone(
              "Found sound card hwconfig (%1): %2",
              cfile,
              entry
            )
            ret = Builtins.add(ret, entry)
          end
        end
      end 


      deep_copy(ret)
    end
  end
end
