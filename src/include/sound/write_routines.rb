# encoding: utf-8

#
# File:
#   write_routines.ycp
#
# Module:
#   Sound
#
# Summary:
#   API for writings sound configuration
#
# Authors:
#   Dan Vesely <dan@suse.cz>
#   Dan Meszaros <dmeszar@suse.cz>
#
#
module Yast
  module SoundWriteRoutinesInclude
    def initialize_sound_write_routines(include_target)
      Yast.import "UI"
      textdomain "sound"

      Yast.import "Arch"
      Yast.import "Sound"
      Yast.import "HWConfig"
      Yast.include include_target, "sound/routines.rb"
    end

    # create special comment for given model
    # @param [String] model card description
    # @param [String] uniq_key unique key
    # @return [String] comment for the alias

    def createAliasComment(model, uniq_key)
      comment = Ops.add(
        Ops.add(Ops.add(Ops.add("# ", uniq_key), ":"), model),
        "\n"
      )
      comment
    end

    def tounprefixedhexstring(i)
      return "" if i == nil

      hex = Builtins.tohexstring(i)

      # remove '0x' prefix, ignore bus type prefix if it is present
      i = Ops.greater_than(Builtins.size(hex), 6) ? 3 : 2

      Builtins.substring(hex, i)
    end

    # Saves one '/etc/modules.conf' entry
    # @param [Hash] entry card config
    # @return [Boolean] success/failure
    def SaveOneModulesEntry(entry)
      entry = deep_copy(entry)
      mod_alias = Builtins.add(
        path(".modprobe_sound.alias"),
        Ops.get_string(entry, "alias", "off")
      )
      mod_alias_comment = Builtins.add(
        Builtins.add(
          path(".modprobe_sound.alias"),
          Ops.get_string(entry, "alias", "off")
        ),
        "comment"
      )

      Builtins.y2milestone("Save card: %1", entry)

      # remove the old configuration file
      if Ops.get_string(entry, "hwcfg", "") != ""
        rm = Ops.add(
          "rm -f /etc/sysconfig/hardware/hwcfg-",
          Ops.get_string(entry, "hwcfg", "")
        )
        Builtins.y2milestone("Removing old configuration file: %1", rm)
        SCR.Execute(path(".target.bash"), rm)
      end

      ret = true
      if Builtins.haskey(entry, "alias")
        module_name = Ops.get_string(entry, "module", "")
        # this is a hack for snd-aoa driver, additional modules are needed (#217300)
        if module_name == "snd-aoa"
          # write the extra module (snd-aoa-i2sbus) to /etc/init.d/sound, add "00" suffix to the alias
          extra_alias = Builtins.add(
            path(".modprobe_sound.alias"),
            Ops.add(Ops.get_string(entry, "alias", "off"), "00")
          )
          ret = ret && SCR.Write(extra_alias, "snd-aoa-i2sbus")
          extra_comment = createAliasComment(
            Ops.get_string(entry, "model", ""),
            Ops.get_string(entry, "unique_key", "")
          )
          ret = ret &&
            SCR.Write(
              Ops.add(extra_alias, "comment"),
              Ops.add("# Extra driver for sound card:\n", extra_comment)
            )

          # write the extra module (snd-aoa-fabric-layout) to /etc/init.d/sound, add "01" suffix to the alias
          extra_alias2 = Builtins.add(
            path(".modprobe_sound.alias"),
            Ops.add(Ops.get_string(entry, "alias", "off"), "01")
          )
          ret = ret && SCR.Write(extra_alias2, "snd-aoa-fabric-layout")
          extra_comment2 = createAliasComment(
            Ops.get_string(entry, "model", ""),
            Ops.get_string(entry, "unique_key", "")
          )
          ret = ret &&
            SCR.Write(
              Ops.add(extra_alias2, "comment"),
              Ops.add("# Extra driver for sound card:\n", extra_comment)
            )
        end

        modcomment = createAliasComment(
          Ops.get_string(entry, "model", ""),
          Ops.get_string(entry, "unique_key", "")
        )

        ret = ret && SCR.Write(mod_alias, module_name)
        ret = ret && SCR.Write(mod_alias_comment, modcomment)

        # load the module automatically on boot
        if entry["bus"] != "pci" && entry["bus"] != "usb" && !module_name.empty?
          Builtins.y2milestone("The soundcard is not attached to PCI or USB")
          Kernel.AddModuleToLoad(module_name)
          ret = Kernel.SaveModulesToLoad
        end
      end
      ret
    end

    # write 'option snd slots=<driver_list>' to the config
    def WriteSlotsOption(slots)
      slots = deep_copy(slots)
      # get the indices
      keys = []

      Builtins.foreach(slots) { |key, val| keys = Builtins.add(keys, key) } 


      keys = Builtins.sort(keys)

      Builtins.y2milestone("Sorted keys: %1", keys)

      drivers = []

      Builtins.foreach(keys) do |k|
        drv = Ops.get(slots, k, "")
        if drv != ""
          drv = "snd-aoa-fabric-layout" if drv == "snd-aoa"

          drivers = Builtins.add(drivers, drv)
        end
      end 


      slot_option = Builtins.mergestring(drivers, ",")

      # write 'snd' options or remove the option line if there is no sound card
      if slot_option != ""
        Builtins.y2milestone("Writing slots option: %1", slot_option)
        SCR.Write(
          Builtins.add(path(".modprobe_sound.options"), "snd"),
          { "slots" => slot_option }
        )
      else
        Builtins.y2milestone("Removing slots option")
        SCR.Write(Builtins.add(path(".modprobe_sound.options"), "snd"), nil)
      end

      nil
    end

    # Removes Kernel modules formerly loaded for sound cards that are being
    # removed now
    def RemovedUnusuedKernelModules
      # TODO: Needs deeper refactoring as knowledge of the data structure should
      #       not be needed.
      #
      # FIXME: Possible issue if the same module is used for another sound card
      #        which stays configured and thus the module should be loaded.
      Sound.removed_info.reject{ |r| r.fetch("module", "").empty? }.each do |r|
        Kernel.RemoveModuleToLoad(r["module"])
      end
      Kernel.SaveModulesToLoad
    end

    # saves modules options. this function has to collect parameters that use
    # different cards that use single module and create a coma separated list of values
    # @param [Array] save_info save info
    # @return [void]
    def SaveModulesOptions(save_info)
      save_info = deep_copy(save_info)
      Builtins.y2milestone("SaveModulesOptions: %1", save_info)

      mod_options = path(".modprobe_sound.options")

      # create distinct list of all modules
      mods = Builtins.toset(
        Builtins.maplist(
          Convert.convert(
            save_info,
            :from => "list",
            :to   => "list <map <string, any>>"
          )
        ) { |card| Ops.get_string(card, "module", "off") }
      )

      # remove the options for unused modules
      configured_options = []

      if Ops.greater_or_equal(
          SCR.Read(path(".target.size"), "/etc/modprobe.d/50-sound.conf"),
          0
        )
        configured_options = SCR.Dir(path(".modprobe_sound.options"))
      else
        # the file doesn't exist, create an empty file
        SCR.Execute(
          path(".target.bash"),
          "/usr/bin/touch /etc/modprobe.d/50-sound.conf"
        )
      end

      # must be called before SaveOneModulesEntry()
      # to write the module back if it is used by another configured card!!
      RemovedUnusuedKernelModules()

      Builtins.foreach(configured_options) do |op|
        if !Builtins.contains(mods, op)
          Builtins.y2milestone("Removing options for unused module %1", op)
          SCR.Write(Builtins.add(path(".modprobe_sound.options"), op), nil)
        end
      end 


      slots = {}

      Builtins.foreach(mods) do |modname|
        res = Sound.CollectOptions(modname)
        # remove "index" option, do not write it
        index = Ops.get_string(res, "index", "")
        res = Builtins.remove(res, "index") if Builtins.haskey(res, "index")
        # remove old "enable" option if it's present
        res = Builtins.remove(res, "enable") if Builtins.haskey(res, "enable")
        indices = Builtins.splitstring(index, ",")
        Builtins.foreach(indices) do |idx|
          i = Builtins.tointeger(idx)
          if i != nil && Ops.greater_or_equal(i, 0)
            Builtins.y2debug("adding %1 : %2", i, modname)
            slots = Builtins.add(slots, i, modname)
          end
        end
        # at first remove the current options (writing empty options leaves the old options untouched)
        SCR.Write(Builtins.add(mod_options, modname), nil)
        SCR.Write(Builtins.add(mod_options, modname), res)
      end

      Builtins.y2milestone("Collected slots: %1", slots)

      WriteSlotsOption(slots)

      nil
    end

    # removeOldAliases
    # @param [Array] als list with old aliases
    def removeOldEntries(als)
      als = deep_copy(als)
      if Ops.greater_or_equal(
          SCR.Read(path(".target.size"), "/etc/modprobe.d/50-sound.conf"),
          0
        )
        Builtins.maplist(
          Convert.convert(als, :from => "list", :to => "list <string>")
        ) do |e|
          if is_snd_alias(e) || Builtins.issubstring(e, "sound-service-") ||
              Builtins.issubstring(e, "sound-slot-")
            SCR.Write(Builtins.add(path(".modprobe_sound.alias"), e), nil)
          end
        end
      end

      nil
    end

    # Remove sound configuration from /etc/modprobe.conf
    def RemoveOldConfiguration
      Builtins.y2milestone(
        "removing old sound configuration from /etc/modprobe.conf (it was already saved to /etc/modprobe.d/50-sound.conf)"
      )

      mod = path(".modules")
      mod_alias = path(".modules.alias")
      mod_options = path(".modules.options")

      if Builtins.contains(SCR.Dir(mod), "alias")
        als = Convert.convert(
          SCR.Read(mod_alias),
          :from => "any",
          :to   => "list <string>"
        )
        Builtins.foreach(als) do |e|
          if is_snd_alias(e) || Builtins.issubstring(e, "sound-service-") ||
              Builtins.issubstring(e, "sound-slot-") ||
              e == "char-major-14" ||
              e == "char-major-116"
            SCR.Write(Builtins.add(mod_alias, e), nil)
          end
        end
      end
      # remove also old options
      Builtins.foreach(Sound.modules_conf_b) do |card|
        modname = Ops.get_string(card, "module", "")
        SCR.Write(Builtins.add(mod_options, modname), nil) if modname != ""
      end
      SCR.Write(mod, nil)

      nil
    end

    def RemoveHWConfig
      ret = true

      # get list of all config files
      cfiles = HWConfig.ConfigFiles
      Builtins.y2milestone("Found sysconfig/hardware files: %1", cfiles)

      # scan each config file - search for sound card config
      Builtins.foreach(cfiles) do |cfile|
        com = HWConfig.GetComment(cfile, "MODULE")
        if com != nil
          coms = Builtins.splitstring(com, "\n")
          sound_card_found = false
          entry = {}

          Builtins.foreach(coms) do |comline|
            # this is a hwconfig file crated by Yast
            # we can safely remove it
            if Builtins.regexpmatch(
                comline,
                "^# YaST configured sound card snd-card-[0-9]*"
              )
              Builtins.y2milestone("Removing file: %1", cfile)
              ret = ret && HWConfig.RemoveConfig(cfile)
            end
          end 


          HWConfig.Flush
        end
      end

      ret
    end

    # Saves all '/etc/modprobe.d/50-sound.conf' entries
    # @param [Array] save_info cards save info
    # @param [Array] system sytem dependent part
    # @return [Hash] return struct: $["return": boolean, "err_msg": string]
    def SaveModulesEntry(save_info, system)
      save_info = deep_copy(save_info)
      system = deep_copy(system)
      Builtins.y2milestone("SaveModulesEntry: %1, %2", save_info, system)

      mod = path(".modprobe_sound")
      mod_alias = path(".modprobe_sound.alias")
      mod_options = path(".modprobe_sound.options")
      SaveModulesOptions(save_info)

      als = []

      err_msg = ""
      if Ops.greater_or_equal(
          SCR.Read(path(".target.size"), "/etc/modprobe.d/50-sound.conf"),
          0
        ) &&
          Builtins.contains(SCR.Dir(mod), "alias")
        als = Convert.to_list(SCR.Read(mod_alias))
      end

      # remove old entries
      removeOldEntries(als)

      # remove old hwconfig files
      RemoveHWConfig()

      if Ops.greater_than(Builtins.size(save_info), 0)
        if !Sound.use_alsa
          if Arch.sparc
            modname = Ops.get_string(save_info, [0, "module"], "off")
            SCR.Write(Builtins.add(mod_alias, "sound"), "sound-slot-0")
          end
        end
      end

      if Builtins.contains(
          Builtins.maplist(
            Convert.convert(
              save_info,
              :from => "list",
              :to   => "list <map <string, any>>"
            )
          ) { |entry| SaveOneModulesEntry(entry) },
          false
        )
        # Error message
        err_msg = Ops.add(
          err_msg,
          Ops.get_string(Sound.STRINGS, "SaveModuleEntry", "")
        )
        return { "return" => false, "err_msg" => err_msg }
      end

      # also this is not neccessary now... (?)
      # if (size(save_info) > 0 && Sound::use_alsa)
      # {
      #
      #     list oss_aliases = alsa_oss(size(save_info));
      #     foreach(map a, (list<map<string,any> >)oss_aliases, ``{
      # 	SCR::Write(add (mod_alias, a["alias"]:""), a["module"]:"");
      #     });
      # }
      SCR.Write(mod, nil)

      # now, when new configuration was succesfully written, we should remove
      # the old one from /etc/modprobe.conf...
      RemoveOldConfiguration() if Sound.used_modprobe_conf

      { "return" => true, "err_msg" => "" }
    end

    # Save volume (for alsa it's alsactl store
    # @return [Boolean] success/failure
    def SaveVolume
      Convert.to_boolean(SCR.Execute(path(".audio.alsa.store"), 0, 0))
    end

    # saves rc values that are stored in map
    # @param [Hash] rc map "variable" : "value", ....
    # @return [String] error string
    def SaveRCValues(rc)
      rc = deep_copy(rc)
      SCR.Write(
        path(".sysconfig.sound.LOAD_SEQUENCER"),
        Ops.get_string(rc, "LOAD_ALSA_SEQ", "no")
      )
      ""
    end
  end
end
