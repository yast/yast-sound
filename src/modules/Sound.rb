# encoding: utf-8

# File:	modules/Sound.ycp
# Package:	Sound configuration
# Summary:	Sound data
# Authors:	Ladislav Slezak <lslezak@suse.cz>
#
require "yast"
require "yaml"

module Yast
  class SoundClass < Module
    def main
      Yast.import "UI"
      textdomain "sound"

      Yast.import "Arch"
      Yast.import "Mode"
      Yast.import "Summary"
      Yast.import "Crash"
      Yast.import "Progress"
      Yast.import "Label"
      Yast.import "String"
      Yast.import "Package"
      Yast.import "Directory"

      # what sound system we're using (true=alsa, false=oss)
      @use_alsa = true

      Yast.include self, "sound/texts.rb"

      # id of current card
      @card_id = 0

      # configuration map of current card
      @save_entry = {}

      # text constants for sound module
      @STRINGS = STRINGS_()

      # flag for letting the module know, that it's launched from then hardware
      # installation screen
      @installation = false

      # was the proposal already generated?
      @proposal_created = false

      # write only mode? (-> do not restart services during writing)
      @write_only = false

      # list for storing detected cards
      @detected_cards = nil

      # list for storing information about removed cards
      @removed_info = []

      # list of detected and unconfigured cards
      @unconfigured_cards = nil

      # settings to save to /etc/modules.conf (only those concerning to sound)
      @modules_conf = []

      # settings to save using .audio.alsa ... mixer
      @volume_settings = []

      # rc settings
      @rc_vars = {}

      # alsa sound card database

      # card list
      @db_cards = nil
      # module details
      @db_modules = nil
      #
      @db_indices = nil

      # map of card vendors
      @db_vendors = nil

      #
      @db_module_index = nil

      @db_packages = nil

      # flag for showing/not showing ui stuff (eg when loading alsa database)
      @use_ui = false

      # currently used card vendor (pointer to table)
      @curr_vendor = ""

      # currently used card driver (pointer to table)
      @curr_driver = ""

      # currently used card model (pointer to table)
      @curr_model = ""

      # default value of volume for new card
      @default_volume = 75

      # This is true, if sound data were read from /etc/modprobe.conf
      # On write, they shoud be removed and written only to /etc/modprobe.d/50-sound.conf
      @used_modprobe_conf = false


      # When true:
      # During autoinstallation, detected cards will be added automaticaly
      # even if they are not defined in control file
      @configure_detected = false

      # Do not detect sounc cards, skip hardware probing
      @skip_detection = false

      # backup structures for sound settings
      @modules_conf_b = nil
      @rc_vars_b = nil
      @volume_settings_b = nil

      @selected_uniq = ""

      # confirm package installation (e.g. alsa-firmware)
      @confirm_packages = true

      # default value of settings modified
      @modified = false

      # ----------- rest of included files:

      Yast.include self, "sound/read_routines.rb"
      Yast.include self, "sound/routines.rb"


      # ----------- function definitions:

      # tiwai: /usr/src/linux/Documentation/sound/alsa/Joystick.txt
      # PCI Cards
      # ---------
      #
      # For PCI cards, the joystick is enabled when the appropriate module
      # option is specified.  Some drivers don't need options, and the
      # joystick support is always enabled.  In the former ALSA version, there
      # was a dynamic control API for the joystick activation.  It was
      # changed, however, to the static module options because of the system
      # stability and the resource management.
      #
      # The following PCI drivers support the joystick natively.
      @joystick_configuration = {
        "snd-als4000"  => { "joystick_port" => "1" },
        "snd-azt3328"  => { "joystick" => "1" },
        "snd-ens1370"  => { "joystick" => "1" },
        "snd-ens1371"  => { "joystick_port" => "1" },
        "snd-cmipci"   => { "joystick_port" => "1" },
        "snd-es1968"   => { "joystick" => "1" },
        "snd-intel8x0" => { "joystick" => "1" },
        "snd-via82xx"  => { "joystick" => "1" },
        "snd-ymfpci"   => { "joystick_port" => "1" }
      }
      Sound()
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      @modified = true

      nil
    end

    # Functions which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    # returns path to the asound.state file
    def asound_state
      "/var/lib/alsa/asound.state"
    end

    # sound module constructor
    def Sound
      @use_alsa = false if Arch.sparc
      Builtins.y2debug("Args: %1", WFM.Args)

      Builtins.maplist(WFM.Args) do |e|
        if Ops.is_string?(e) && e == ".oss"
          @use_alsa = false
          Builtins.y2milestone("Using OSS")
        end
      end

      Builtins.y2debug("use ALSA: %1", @use_alsa)

      nil
    end

    # Probe one card with alsaconf call
    # @param [String] chip chip name
    # @return non-empty string with card options when card is present
    def ProbeOldChip(chip)
      command = Builtins.sformat("/usr/sbin/alsaconf -p %1", chip)
      name = Ops.get_string(
        @db_modules,
        [Ops.add("snd-", chip), "description"],
        chip
      )

      # yes/no popup text, %1 is chip name
      if Crash.AskRun(
          command,
          Builtins.sformat(
            _(
              "It looks like probing the chip\n" +
                "%1\n" +
                "failed last time.\n" +
                "\n" +
                "Probe the chip now?\n"
            ),
            name
          )
        )
        Crash.Run(command)
        out = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
        Crash.Finish(command)
        if Ops.get_string(out, "stderr", "") != ""
          Builtins.y2warning(
            "alsaconf returns error: %1",
            Ops.get_string(out, "stderr", "")
          )
        end

        if Ops.get_integer(out, "exit", 1) == 0
          return Ops.get_string(out, "stdout", "")
        end
      end
      ""
    end

    # Detect old ISA cards (which hwinfo doesn't know) using alsaconf
    # @return success
    def DetectOldCards
      chips = [
        "opl3sa2",
        "cs4236",
        "cs4232",
        "cs4231",
        "es18xx",
        "es1688",
        "sb16",
        "sb8"
      ]

      command = "/usr/sbin/alsaconf -P"
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      return false if Ops.get_integer(out, "exit", 1) != 0
      out_str = Builtins.deletechars(Ops.get_string(out, "stdout", ""), "\n")
      chips = Builtins.splitstring(out_str, " ") if out_str != ""

      probelist = []
      Builtins.foreach(chips) do |chip|
        name = Ops.get_string(
          @db_modules,
          [Ops.add("snd-", chip), "description"],
          ""
        )
        if name != ""
          name = Builtins.sformat("%1 (%2)", name, chip)
        else
          name = chip
        end
        probelist = Builtins.add(probelist, Item(Id(chip), name, true))
      end

      height = Ops.add(Builtins.size(chips), 12)
      height = 25 if Ops.greater_than(height, 25)

      UI.OpenDialog(
        HBox(
          VSpacing(height),
          HSpacing(1),
          VBox(
            HSpacing(50),
            VSpacing(0.5),
            # label
            Label(
              Id(:l),
              _(
                "No card was found.\n" +
                  "Attempt to detect the presence some old chips?\n" +
                  "\n" +
                  "Warning: The probe procedure can take some time and\n" +
                  "could make your system unstable.\n"
              )
            ),
            VSpacing(),
            MultiSelectionBox(
              Id(:probelist),
              # selection box label
              _("&Select the Drivers to Probe"),
              probelist
            ),
            HBox(
              # button label
              PushButton(Id(:ok), Opt(:key_F10, :default), _("&Yes, Probe")),
              # button label
              PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
            ),
            VSpacing(0.5)
          ),
          HSpacing(1)
        )
      )

      ret = Convert.to_symbol(UI.UserInput)
      if ret == :ok
        chips = Convert.convert(
          UI.QueryWidget(Id(:probelist), :SelectedItems),
          :from => "any",
          :to   => "list <string>"
        )

        UI.OpenDialog(
          HBox(
            VSpacing(7),
            VBox(
              HSpacing(40),
              # popup dialog header
              Label(_("Probing:")),
              HBox(HWeight(1, Label(Id(:probed), ""))),
              # progress bar label
              ProgressBar(
                Id(:progress),
                _("Progress:"),
                Builtins.size(chips),
                0
              ),
              VSpacing(0.5),
              PushButton(Id(:abort), Opt(:key_F9), Label.AbortButton)
            )
          )
        )
        aborted = false
        Builtins.foreach(chips) do |chip|
          next if aborted
          aborted = UI.PollInput == :abort
          UI.ChangeWidget(
            Id(:probed),
            :Value,
            Ops.get_string(
              @db_modules,
              [Ops.add("snd-", chip), "description"],
              chip
            )
          )
          ret2 = ProbeOldChip(chip)
          if ret2 != ""
            # parse the output and add new entry to detected_cards
            chip = Builtins.sformat("snd-%1", chip)
            returned = Builtins.splitstring(ret2, "\n")
            Builtins.y2milestone("probed with alsaconf: %1", returned)
            # label (%1 is name of the chip)
            default_name = Builtins.sformat(
              _("Card with %1 Chip"),
              Ops.get_string(@db_modules, [chip, "description"], chip)
            )
            model = Ops.get_string(returned, 1, default_name)
            model = default_name if model == ""
            ret2 = Ops.get_string(returned, 0, "")

            options = {}
            Builtins.foreach(Builtins.splitstring(ret2, " ")) do |o|
              op = Builtins.splitstring(o, "=")
              if Builtins.size(op) == 2
                options = Builtins.add(
                  options,
                  Ops.get_string(op, 0, ""),
                  Ops.get_string(op, 1, "")
                )
              end
            end

            @detected_cards = Builtins.add(
              @detected_cards,
              {
                "model"             => model,
                "module"            => chip,
                "options"           => options,
                "alsaconf_detected" => true
              }
            )
          end
          # advance the progress bar
          UI.ChangeWidget(
            Id(:progress),
            :Value,
            Ops.add(
              Convert.to_integer(UI.QueryWidget(Id(:progress), :Value)),
              1
            )
          )
        end
        UI.CloseDialog #progress window
      end
      UI.CloseDialog
      true
    end

    # do hardware detection
    # @return [Boolean] success/failure
    def DetectHardware
      if Mode.test
        @detected_cards = [
          {
            "bus"            => "PCI",
            "class_id"       => 4,
            "device"         => "SB Live! EMU10000",
            "device_id"      => 65538,
            "drivers"        => [
              {
                "active"   => false,
                "modprobe" => true,
                "modules"  => [["emu10k1", ""]]
              }
            ],
            "old_unique_key" => "LaV9.FfCiMJnnUxC",
            "resource"       => {
              "io"  => [
                {
                  "active" => true,
                  "length" => 0,
                  "mode"   => "rw",
                  "start"  => 49152
                }
              ],
              "irq" => [{ "count" => 41833, "enabled" => true, "irq" => 10 }]
            },
            "rev"            => "7",
            "slot_id"        => 5,
            "sub_class_id"   => 1,
            "sub_device"     => "CT4832 SBLive! Value",
            "sub_device_id"  => 98343,
            "sub_vendor"     => "Creative Labs",
            "sub_vendor_id"  => 69890,
            "unique_key"     => "CvwD.FfCiMJnnUxC",
            "vendor"         => "Creative Labs",
            "vendor_id"      => 69890
          }
        ]
        return true
      end

      @detected_cards = [] if Mode.config

      if @skip_detection
        @detected_cards = []
        return true
      end

      # do noop if cards were already detected
      return true if Ops.greater_than(Builtins.size(@detected_cards), 0)
      @detected_cards = Convert.convert(
        SCR.Read(path(".probe.sound")),
        :from => "any",
        :to   => "list <map>"
      )
      true
    end


    # searches for sound alias in /etc/modules.conf
    # @return [void]
    def ReadModulesConf
      @modules_conf = read_save_info
      Builtins.y2milestone("read_save_info: %1", @modules_conf)

      nil
    end


    # returns list of autodetected sound cards that haven't been already
    # configured
    # @param [Array<Hash>] save_info list of already configured cards
    # @return [Array] of unconfigured cards
    def getConfigurableCards(save_info)
      save_info = deep_copy(save_info)
      snd = deep_copy(@detected_cards)
      snd = filter_configured(save_info, snd)

      # create save_info entries
      if Ops.greater_than(Builtins.size(snd), 0)
        if !@use_alsa
          snd = Builtins.maplist(snd) do |card|
            options = Ops.get_list(card, "options", [])
            opts = {}
            Builtins.maplist(options) do |op|
              if Ops.get_string(op, "default", "") != ""
                opts = Builtins.add(
                  opts,
                  Ops.get_string(op, "name", ""),
                  Ops.get_string(op, "default", "")
                )
              end
            end
            modname = ""
            drivers = Ops.get_list(card, "drivers", [])
            if Ops.greater_than(Builtins.size(drivers), 0)
              driver = Ops.get_map(drivers, 0, {})
              m = Ops.get_list(driver, "modules", [])
              if Ops.greater_than(Builtins.size(m), 0)
                modname = Ops.get_string(m, [0, 0], "")
                modname = String.FirstChunk(modname, ".")
              end
            end
            {
              "model"      => get_card_label(card),
              "module"     => modname,
              "unique_key" => Ops.get_string(card, "unique_key", ""),
              "options"    => opts
            }
          end
        else
          snd = Builtins.maplist(snd) do |card|
            if Ops.get_boolean(card, "alsaconf_detected", false)
              next deep_copy(card)
            end
            # get all the apropriate information from the database
            mod = get_module(card)
            next {} if mod == {}
            opts = {}
            Builtins.maplist(Ops.get_map(mod, "params", {})) do |op, data|
              if Ops.get_string(data, "default", "") != ""
                opts = Builtins.add(
                  opts,
                  op,
                  Ops.get_string(data, "default", "")
                )
              end
            end
            entry = {
              "model"         => get_card_label(card),
              "module"        => Ops.get_string(mod, "name", ""),
              "unique_key"    => Ops.get_string(card, "unique_key", ""),
              "options"       => opts,
              "bus"           => Ops.get_string(card, "bus_hwcfg", ""),
              "bus_id"        => Ops.get_string(card, "sysfs_bus_id", ""),
              "vendor_id"     => Ops.get_integer(card, "vendor_id", 0),
              "sub_vendor_id" => Ops.get_integer(card, "sub_vendor_id", 0),
              "device_id"     => Ops.get_integer(card, "device_id", 0),
              "sub_device_id" => Ops.get_integer(card, "sub_device_id", 0)
            }
            deep_copy(entry)
          end
        end
        # filter out modules with unspecified module name
        # (sound card not supported by alsa / no module found)
        snd = Builtins.filter(snd) { |e| Ops.get_string(e, "module", "") != "" }
      end
      deep_copy(snd)
    end

    # update list of unconfigured cards
    # (necessary when deleting configured card)
    # @return [void]
    def UpdateUnconfiguredCards
      @unconfigured_cards = getConfigurableCards(@modules_conf)

      nil
    end

    def PollAbort
      UI.PollInput == :abort
    end

    # opens alsa sound cards database
    # @return [void]
    def LoadDatabase(use_ui)
      sound_db = {}
      if @db_cards == nil || @db_cards == {}
        textdomain "sound_db"
        Builtins.y2debug("Reading card database")

	sound_db = YAML.load_file(Directory.datadir + "/sndcards.yml") rescue {}

        @db_cards = Ops.get_map(sound_db, "cards", {})
        @db_modules = Ops.get_map(sound_db, "modules", {})
        @db_indices = Ops.get_map(sound_db, "indices", {})
        @db_module_index = Ops.get_map(sound_db, "mod_idx", {})

        @db_vendors = Ops.get_map(sound_db, "vendors", {})

        textdomain "sound"
      end

      nil
    end

    # opens alsa sound cards database
    # @return [void]
    def LoadPackageDatabase
      Builtins.y2milestone("Reading required packages database...")
      @db_packages = YAML.load_file(Directory.datadir + "/alsa_packages.yml") rescue {}

      Builtins.y2milestone(
        "Loaded package list for %1 drivers",
        Builtins.size(@db_packages)
      )

      nil
    end

    def RequiredPackages(driver)
      LoadPackageDatabase() if @db_packages == nil

      ret = Ops.get_list(@db_packages, driver, [])
      Builtins.y2milestone("Driver %1 requires packages: %2", driver, ret)

      deep_copy(ret)
    end

    def RequiredPackagesToInstall(driver)
      req_pkgs = RequiredPackages(driver)
      req_pkgs = Builtins.filter(req_pkgs) do |pkg|
        !Package.PackageInstalled(pkg)
      end

      Builtins.y2milestone(
        "Required packages to install for driver %1: %2",
        driver,
        req_pkgs
      )
      deep_copy(req_pkgs)
    end

    def RequiredPackagesToInstallSummary(driver)
      req_pkgs = RequiredPackagesToInstall(driver)
      pkg_summary = ""

      if Ops.greater_than(Builtins.size(req_pkgs), 0)
        # summary string, %1 is a list of packages
        pkg_summary = Builtins.sformat(
          _("Required packages to install: %1"),
          # separator for constructing package list
          Builtins.mergestring(req_pkgs, _(", "))
        )
      end

      pkg_summary
    end

    # Read all sound settings from the SCR
    # @param [Boolean] interactive if user could be asked for actions
    #	(currently only for detecting with alsaconf)
    # @return [Boolean] True on success
    def Read(interactive)
      # sound Read dialog caption:
      caption = _("Initializing Sound Configuration")

      if Mode.test
        DetectHardware()
        @modules_conf = []
        @rc_vars = {}
        UpdateUnconfiguredCards()
        return true
      end
      return false if interactive && PollAbort()

      # load cards database
      LoadDatabase(interactive)

      # load data from /etc/modules.conf
      ReadModulesConf()

      # detect sound cards
      DetectHardware()

      # check old isa cards (bug25285)
      if interactive && @detected_cards == [] && @modules_conf == []
        DetectOldCards()
      end

      @rc_vars = read_rc_vars

      @volume_settings = get_vol_settings

      # create list of unconfigured cards
      UpdateUnconfiguredCards()

      true
    end

    def ExportVolumeSettings(volume_setup)
      volume_setup = deep_copy(volume_setup)
      Builtins.y2milestone("ExportVolumeSettings: %1", volume_setup)
      ret = []

      return deep_copy(ret) if volume_setup == nil

      Builtins.foreach(volume_setup) do |card|
        channels = []
        Builtins.foreach(
          Convert.convert(card, :from => "list", :to => "list <list>")
        ) do |channel|
          ch = {
            "name"   => Ops.get_string(channel, 0, "unknown"),
            "volume" => Ops.get_integer(channel, 1, 0),
            "mute"   => Ops.get_boolean(channel, 2, false)
          }
          channels = Builtins.add(channels, ch)
        end
        ret = Builtins.add(ret, channels)
      end 


      Builtins.y2milestone("Exported volume setting: %1", ret)

      deep_copy(ret)
    end

    def ImportVolumeSettings(volume_setup)
      volume_setup = deep_copy(volume_setup)
      ret = []

      Builtins.y2milestone("ImportVolumeSettings: %1", volume_setup)

      return deep_copy(ret) if volume_setup == nil

      Builtins.foreach(
        Convert.convert(volume_setup, :from => "list", :to => "list <list>")
      ) do |card|
        channels = []
        Builtins.foreach(card) do |channel|
          ch = []
          if Ops.is_map?(channel)
            channel_map = Convert.to_map(channel)

            # convert map to list
            ch = Builtins.add(
              ch,
              Ops.get_string(channel_map, "name", "unknown")
            )
            ch = Builtins.add(ch, Ops.get_integer(channel_map, "volume", 0))
            ch = Builtins.add(ch, Ops.get_boolean(channel_map, "mute", false))
          elsif Ops.is_list?(channel)
            # use the list
            ch = Convert.to_list(channel)
          else
            # wrong type
            Builtins.y2error(
              "Wrong channel configuration '%1', expected list or map!",
              channel
            )
          end
          channels = Builtins.add(channels, ch)
        end
        ret = Builtins.add(ret, channels)
      end 


      Builtins.y2milestone("Imported volume setting: %1", ret)

      deep_copy(ret)
    end


    # Just Set module data
    # @param [Hash] settings Sound configuration settings
    # @return [void]
    def Set(settings)
      settings = deep_copy(settings)
      @modules_conf = Ops.get_list(settings, "modules_conf", [])
      @rc_vars = Ops.get_map(settings, "rc_vars", {})
      @volume_settings = ImportVolumeSettings(
        Ops.get_list(settings, "volume_settings", [])
      )
      @configure_detected = Ops.get_boolean(
        settings,
        "configure_detected",
        false
      )

      nil
    end

    # Get all sound settings from the first parameter
    # (For autoinstallation use.)
    # @param [Hash] settings settings to import
    # @return [Boolean] True on success
    def Import(settings)
      settings = deep_copy(settings)
      # initialize these unneeded values
      @detected_cards = []
      @unconfigured_cards = []

      Set(settings)

      true
    end

    # Dump the sound settings to a single map. self explaining
    # (For use by autoinstallation.)
    # @return [Hash] Dumped settings (later acceptable by Import())
    def Export
      {
        "modules_conf"       => @modules_conf,
        "rc_vars"            => @rc_vars,
        "volume_settings"    => ExportVolumeSettings(@volume_settings),
        "configure_detected" => @configure_detected
      }
    end

    # Get list of all kernel modules which are requied by the configured cards
    # @return [Array] Unique list of modules
    def RequiredKernelModules
      # list of all unique modules
      mods = []

      if @modules_conf != nil &&
          Ops.greater_than(Builtins.size(@modules_conf), 0)
        Builtins.foreach(@modules_conf) do |m|
          modname = Ops.get_string(m, "module", "")
          if m != nil && Ops.greater_than(Builtins.size(m), 0)
            mods = Builtins.add(mods, modname)
          end
        end
      end

      # remove duplicates
      mods = Builtins.toset(mods)

      Builtins.y2milestone("Required kernel modules: %1", mods)

      deep_copy(mods)
    end

    def AllRequiredPackagesInstalled
      all_mods = RequiredKernelModules()
      ret = true

      Builtins.foreach(all_mods) do |mod|
        if Ops.greater_than(Builtins.size(RequiredPackagesToInstall(mod)), 0)
          ret = false
        end
      end 


      Builtins.y2milestone("All required packages are installed: %1", ret)
      ret
    end

    # Update the SCR according to sound settings
    # @return [Boolean] True on success
    def Write
      if Mode.test == false
        settings = Export()
        WFM.CallFunction("sound_write", [settings])
      end
      true
    end

    # returns html formated configuration summary
    # @return [String] Summary string
    def Summary
      keys = Builtins.maplist(@modules_conf) do |card|
        Ops.get_string(card, "unique_key", "...")
      end

      retlist = Builtins.maplist(@modules_conf) do |card|
        package_summary = RequiredPackagesToInstallSummary(
          Ops.get_string(card, "module", "")
        )
        if package_summary != ""
          package_summary = Ops.add("<BR>", package_summary)
        end
        Summary.Device(
          Ops.get_string(card, "model", "Sound card"),
          Ops.add(
            # summary text: '(sound card is) Configured as snd-card-1'
            Builtins.sformat(
              _("Configured as %1."),
              Ops.get_string(card, "alias", "snd-card-0")
            ),
            package_summary
          )
        )
      end

      if @detected_cards != nil
        Builtins.foreach(@detected_cards) do |card|
          if !Builtins.contains(keys, Ops.get_string(card, "unique_key", "..."))
            retlist = Builtins.add(
              retlist,
              Summary.Device(get_card_label(card), Summary.NotConfigured)
            )
          end
        end
      else
        Builtins.y2milestone("detected_cards: nil")
      end

      Summary.DevicesList(retlist)
    end

    # this function converts options for modules from 'modules_conf'
    # data structure to another - it is needed for writing options to
    # /etc/modules conf.
    # eg. we have these configured cards:
    # [
    #	$["model": "sblive", "module":"snd-emu10k1",
    #	  "options" :$["opt1": "a", "opt2": "b"]],
    #  $["model": "sblive", "module":"snd-emu10k1",
    #	  "options": $["opt2": "c"]],
    #  $["model": "other", "module":"mod2",
    #	  "options": $["opt1": "a", "opt2": "b"]]
    # ]
    # CollectOptions ("snd-emu10k1") returns $["opt1":"a,", "opt2":"b,c"]
    # @param [String] modname module name
    # @return [Hash] Map with collected options
    #
    def CollectOptions(modname)
      # first filter out entries with other module
      mod_entries = Builtins.filter(@modules_conf) do |e|
        Ops.get_string(e, "module", "off") == modname
      end

      Builtins.y2debug("modules_conf: %1", @modules_conf)
      # create list of options (list of maps)
      mod_opts = Builtins.maplist(
        Convert.convert(mod_entries, :from => "list", :to => "list <map>")
      ) { |e| Ops.get_map(e, "options", {}) }
      opts = []

      Builtins.foreach(mod_opts) { |card_opts| Builtins.foreach(card_opts) do |name, val|
        opts = Builtins.add(opts, name)
      end }
      opts = Builtins.toset(opts)
      opts = Builtins.filter(opts) { |e| e != "snd_id" } # not neccessary?

      res = {}
      # get the default module parameters from database
      params = get_module_params(modname)
      Builtins.y2milestone("Default module parameters: %1", params)
      # for each option collect their values

      Builtins.y2milestone("options: %1", opts)
      Builtins.y2milestone("module options: %1", mod_opts)

      Builtins.foreach(opts) do |opname|
        value = ""
        # is the value first?
        first_value = true
        # all options are default, not configured by user
        only_default = true
        Builtins.foreach(mod_opts) do |card_opts|
          # add the separator if needed
          value = Ops.add(value, ",") if !first_value
          # value for the card
          card_option_value = Ops.get_string(card_opts, opname, "")
          default_value = Ops.get_string(params, [opname, "default"], "")
          Builtins.y2debug("card_option_value: '%1'", card_option_value)
          Builtins.y2debug("default_value: '%1'", default_value)
          if card_option_value != default_value && card_option_value != ""
            only_default = false
          end
          # use default if if the value is not defined
          card_option_value = default_value if card_option_value == ""
          value = Ops.add(value, card_option_value)
          first_value = false
        end
        Builtins.y2debug("only_default: %1", only_default)
        # don't add the default options
        if !only_default || opname == "index"
          res = Builtins.add(res, opname, value)
        end
      end

      Builtins.y2milestone("collected options: %1", res)
      deep_copy(res)
    end

    # creates list of command that will be used for sound system start
    # (emulates 'rcalsasound start' somehow)
    # @return [Array] of shell commands
    def CreateModprobeCommands
      outlist = []
      # create distinct list of all modules
      mods = Builtins.toset(Builtins.maplist(@modules_conf) do |e|
        Ops.get_string(e, "module", "off")
      end)
      Builtins.maplist(
        Convert.convert(mods, :from => "list", :to => "list <string>")
      ) do |modname|
        opts = CollectOptions(modname)
        if Builtins.haskey(opts, "index")
          # ignore "index" options
          opts = Builtins.remove(opts, "index")
        end
        optstr = ""
        Builtins.maplist(
          Convert.convert(opts, :from => "map", :to => "map <string, string>")
        ) { |k, v| optstr = Ops.add(optstr, Builtins.sformat(" %1=%2", k, v)) }
        # we need to tell 'modprobe' not to look into modules.conf now,
        # because it may contain messed options for the module %1 that
        # would break the module loading. (modprobe will merge options
        # specified in param %2 with those specified in modules.conf)
        modprobe = Builtins.sformat(
          "/sbin/modprobe -C /dev/null %1 %2",
          modname,
          optstr
        )
        outlist = Builtins.add(outlist, modprobe)
      end

      # add the extra module
      if Builtins.contains(mods, "snd-aoa")
        Builtins.y2milestone(
          "Adding extra module: snd-aoa-i2sbus, snd-aoa-fabric-layout"
        )
        outlist = Builtins.add(
          outlist,
          "/sbin/modprobe -C /dev/null snd-aoa-i2sbus"
        )
        outlist = Builtins.add(
          outlist,
          "/sbin/modprobe -C /dev/null snd-aoa-fabric-layout"
        )
      end

      Builtins.y2milestone("Modprobe commands: %1", outlist)

      deep_copy(outlist)
    end

    # reset settings.
    # used at installation time when user invokes 'reset to original proposal'
    def ForceReset
      @modules_conf = []
      DetectHardware()
      UpdateUnconfiguredCards()
      @proposal_created = false

      nil
    end

    # create a proposal
    # @return [Boolean] success/failure
    def Propose
      return true if @proposal_created
      # to enable initialization, run ForceReset for first time,
      # even if "force_reset" parameter was not set
      # TODO: but if force_reset is set, ForceReset is run twice!
      ForceReset()

      # fix for nm256 cards: see bug #10384: leave this card unconfigured.
      # loading of this module fails under some notebooks, nm256 module
      # also makes some problems on other notebooks: there are detected
      # two cards on some machines, althrough there is a sinlge card.
      # two cards are detected: one that use opl3sa module and second one
      # that uses nm256.
      # let's solve this problem by filtering the nm256 module out.
      @unconfigured_cards = Builtins.filter(@unconfigured_cards) do |card|
        Ops.get_string(card, "module", "") != "snd-nm256"
      end

      @modules_conf = recalc_save_entries(@unconfigured_cards)

      # card of Thinkpad 600E must be configured manually
      @modules_conf = Builtins.filter(@modules_conf) do |card|
        ok = true
        Builtins.foreach(@detected_cards) do |c|
          if Ops.get_string(c, "unique_key", "") ==
              Ops.get_string(card, "unique_key", "") &&
              Ops.get_integer(c, "sub_device_id", 0) == 69648 &&
              Ops.get_integer(c, "sub_vendor_id", 0) == 69652 &&
              Ops.get_string(card, "module", "") != "snd-cs4236"
            ok = false
          end
        end
        ok
      end

      @rc_vars = { "LOAD_ALSA_SEQ" => "yes" }
      @proposal_created = true
      true
    end

    # copy settings to backup variables
    def StoreSettings
      @modules_conf_b = deep_copy(@modules_conf)
      @rc_vars_b = deep_copy(@rc_vars)
      @volume_settings_b = deep_copy(@volume_settings)

      nil
    end

    # restore settings from backup variables
    def RestoreSettings
      if @modules_conf_b == nil
        Builtins.y2error(
          "restoring sound setting without storing them before. bailing out."
        )
      end
      @modules_conf = deep_copy(@modules_conf_b)
      @rc_vars = deep_copy(@rc_vars_b)
      @volume_settings = deep_copy(@volume_settings_b)

      nil
    end

    # Status of configuration
    # @return [Boolean] true if configuration was changed
    def Changed
      return true if @modules_conf != @modules_conf_b || @rc_vars != @rc_vars_b
      false
    end

    # returns list of configured/proposed sound cards.
    # @return [Array] of maps: [$["name": "ASDASD", "card_no": 0]...]
    def GetSoundCardList
      if @installation || Mode.autoinst
        pos = -1
        return Builtins.maplist(@modules_conf) do |card|
          pos = Ops.add(pos, 1)
          {
            "name"    => Ops.get_locale(card, "model", _("Sound card")),
            "card_no" => pos
          }
        end
      else
        cards_path = path(".audio.alsa.cards")
        cards_numbers = SCR.Dir(cards_path)
        cards = []

        cards = Builtins.maplist(cards_numbers) do |card_no|
          curcard_path = Builtins.add(
            cards_path,
            Builtins.sformat("%1", card_no)
          )
          {
            "card_no" => Builtins.tointeger(card_no),
            "name"    => SCR.Read(Ops.add(curcard_path, path(".name")))
          }
        end if cards_numbers != nil
        Builtins.y2milestone("List of the sound cards: %1", cards)
        return deep_copy(cards)
      end
    end

    # stores unique keys. this function is not part of sound_write module
    # because it should not be called during autoinstallation
    #
    def StoreUniqueKeys
      UpdateUnconfiguredCards()
      conf = Builtins.maplist(@modules_conf) do |e|
        Ops.get_string(e, "unique_key", "")
      end
      unconf = Builtins.maplist(@unconfigured_cards) do |e|
        Ops.get_string(e, "unique_key", "")
      end
      SaveUniqueKeys(conf, unconf)

      nil
    end

    # Get joystick settings from sound database
    # @param [String] modname name of sound module
    # @return [Hash] map with options
    def GetJoystickSettings(modname)
      Ops.get_map(@db_modules, [modname, "joystick"], {})
    end

    # store mixer settings
    def StoreMixer
      return if Builtins.size(SCR.Dir(path(".audio.alsa.cards"))) == 0
      @volume_settings = []
      p = nil
      cards = SCR.Dir(path(".audio.alsa.cards"))
      Builtins.maplist(cards) do |c|
        p = Builtins.topath(
          Builtins.sformat(".audio.alsa.cards.%1.channels", c)
        )
        channels = SCR.Dir(p)
        Builtins.maplist(channels) do |ch|
          p = Builtins.topath(
            Builtins.sformat(".audio.alsa.cards.%1.channels.%2.mute", c, ch)
          )
          if !Convert.to_boolean(SCR.Read(p))
            p = Builtins.topath(
              Builtins.sformat(".audio.alsa.cards.%1.channels.%2.volume", c, ch)
            )

            # add the channel
            tmp = Ops.get(@volume_settings, Builtins.tointeger(c), [])
            tmp = Builtins.add(tmp, [ch, SCR.Read(p), "false"])

            Ops.set(@volume_settings, Builtins.tointeger(c), tmp)
          end
        end
      end

      nil
    end


    # sets the channel volume to value [0..100]
    # @param [Fixnum] c_id card #
    # @param [String] channel channel name
    # @param [Fixnum] value volume of channel [0..100]
    # @return success
    def SetVolume(c_id, channel, value)
      # two cases: we have sound system already running:
      if !Mode.config &&
          Ops.greater_than(
            Builtins.size(SCR.Dir(path(".audio.alsa.cards"))),
            c_id
          )
        p = Builtins.sformat(
          ".audio.alsa.cards.%1.channels.%2.volume",
          c_id,
          channel
        )
        p2 = Builtins.sformat(
          ".audio.alsa.cards.%1.channels.%2.mute",
          c_id,
          channel
        )
        SCR.Write(Builtins.topath(p2), false)
        return SCR.Write(Builtins.topath(p), value)
      else
        # alsa is not running. probably autoinstallation or someone wants
        # to change proposed volume
        # store volume to volume_settings datastricure in autoinstallation

        tmp = Ops.get(@volume_settings, c_id, [])

        found = false
        updated_channels = []
        Builtins.foreach(tmp) do |ch|
          new_ch = deep_copy(ch)
          if Ops.get_string(new_ch, 0, "") == channel
            Ops.set(new_ch, 1, value)
            found = true
          end
          updated_channels = Builtins.add(updated_channels, new_ch)
        end 


        if found
          # the channel has been found, use the updates list
          tmp = deep_copy(updated_channels)
        else
          # the channel has not been found, add it to the list
          tmp = Builtins.add(tmp, [channel, value, false])
        end

        Ops.set(@volume_settings, c_id, tmp)
        return true
      end
    end

    # initialises volume after adding a new card.
    # unmutes and sets volume for some channels
    # @param [Fixnum] c_id card id.
    # @param [String] modname name of sound module
    def InitMixer(c_id, modname)
      Builtins.y2milestone("InitMixer: %1, %2", c_id, modname)

      devs = Convert.convert(
        Ops.get(@db_modules, [modname, "mixer"]) do
          {
            "Master"      => @default_volume,
            "PCM"         => @default_volume,
            "CD"          => @default_volume,
            "Synth"       => @default_volume,
            "Front"       => @default_volume,
            "Headphone"   => @default_volume,
            "Master Mono" => @default_volume,
            "iSpeaker"    => @default_volume
          }
        end,
        :from => "any",
        :to   => "map <string, integer>"
      )

      Builtins.y2milestone("Mixer devices: %1", devs)

      # now let's merge settings from volume_settings list
      if Ops.is_list?(Ops.get(@volume_settings, c_id))
        Builtins.y2milestone(
          "cvolume_settings[c_id]:nil: %1",
          Ops.get(@volume_settings, c_id)
        )
        Builtins.foreach(Ops.get(@volume_settings, c_id, [])) do |channel|
          Builtins.y2debug("devs: %1", devs)
          Builtins.y2debug("channel: %1", channel)
          # do not rewrite the values from DB
          if !Builtins.haskey(devs, Ops.get_string(channel, 0, "Master"))
            devs = Builtins.add(
              devs,
              Ops.get_string(channel, 0, "Master"),
              Ops.get_integer(channel, 1, @default_volume)
            )
          end
        end
      end
      Builtins.y2milestone("Mixer devices after merge: %1", devs)

      devs2 = []

      Builtins.foreach(
        Convert.convert(devs, :from => "map", :to => "map <string, integer>")
      ) do |dev, vol|
        SetVolume(c_id, dev, vol)
        Builtins.y2milestone(
          "Set volume: card: %1, channel: %2, volume: %3",
          c_id,
          dev,
          vol
        )
        devs2 = Builtins.add(devs2, dev)
      end

      Builtins.y2milestone("unmute devices: %1", devs2)
      unmute(devs2, c_id)

      nil
    end

    # Test whether sound card supports joystick
    # @param [Fixnum] c_id id of sound card
    # @return [Boolean] True if sound card c_id supports joystick
    def HasJoystick(c_id)
      return false if c_id == nil
      if @use_alsa == true
        entry = Ops.get(@modules_conf, c_id, {})
        modname = Ops.get_string(entry, "module", "")

        return Ops.get_map(@db_modules, [modname, "joystick"], {}) != {}
      else
        return false
      end
    end

    # Return list of configured/proposed sound cards which support joystick
    # @return [Array] list of maps: [$["card_no":0, "name":"Sound Blaster Live!"]]
    def GetSoundCardListWithJoy
      # get list of installed sound cards
      cards = GetSoundCardList()

      # cards which support joysticks
      filtered = []

      # remove cards without joystick support
      Builtins.foreach(
        Convert.convert(
          cards,
          :from => "list",
          :to   => "list <map <string, any>>"
        )
      ) do |card|
        cid = Ops.get_integer(card, "card_no", -2)
        if cid != -2 && HasJoystick(cid) == true
          filtered = Builtins.add(filtered, card)
        end
      end

      deep_copy(filtered)
    end

    def SetConfirmPackages(ask)
      Builtins.y2milestone("Confirm additional package installation: %1", ask)
      @confirm_packages = ask

      nil
    end

    def ConfirmPackages
      @confirm_packages
    end

    publish :variable => :use_alsa, :type => "boolean"
    publish :variable => :card_id, :type => "integer"
    publish :variable => :save_entry, :type => "map"
    publish :variable => :STRINGS, :type => "map"
    publish :variable => :installation, :type => "boolean"
    publish :variable => :proposal_created, :type => "boolean"
    publish :variable => :write_only, :type => "boolean"
    publish :variable => :detected_cards, :type => "list <map>"
    publish :variable => :removed_info, :type => "list <map>"
    publish :variable => :unconfigured_cards, :type => "list <map>"
    publish :variable => :modules_conf, :type => "list <map>"
    publish :variable => :volume_settings, :type => "list <list <list>>"
    publish :variable => :rc_vars, :type => "map"
    publish :variable => :db_cards, :type => "map"
    publish :variable => :db_modules, :type => "map"
    publish :variable => :db_indices, :type => "map"
    publish :variable => :db_vendors, :type => "map"
    publish :variable => :db_module_index, :type => "map"
    publish :variable => :db_packages, :type => "map"
    publish :variable => :use_ui, :type => "boolean"
    publish :variable => :curr_vendor, :type => "string"
    publish :variable => :curr_driver, :type => "string"
    publish :variable => :curr_model, :type => "string"
    publish :variable => :default_volume, :type => "integer"
    publish :variable => :used_modprobe_conf, :type => "boolean"
    publish :variable => :configure_detected, :type => "boolean"
    publish :variable => :skip_detection, :type => "boolean"
    publish :variable => :modules_conf_b, :type => "list <map>"
    publish :variable => :selected_uniq, :type => "string"
    publish :variable => :modified, :type => "boolean"
    publish :function => :SetModified, :type => "void ()"
    publish :function => :GetModified, :type => "boolean ()"
    publish :function => :LoadDatabase, :type => "void (boolean)"
    publish :function => :CreateModprobeCommands, :type => "list ()"
    publish :function => :ProbeOldChip, :type => "string (string)"
    publish :function => :asound_state, :type => "string ()"
    publish :variable => :joystick_configuration, :type => "map"
    publish :function => :Sound, :type => "void ()"
    publish :function => :DetectOldCards, :type => "boolean ()"
    publish :function => :DetectHardware, :type => "boolean ()"
    publish :function => :ReadModulesConf, :type => "void ()"
    publish :function => :getConfigurableCards, :type => "list <map> (list <map>)"
    publish :function => :UpdateUnconfiguredCards, :type => "void ()"
    publish :function => :PollAbort, :type => "boolean ()"
    publish :function => :LoadPackageDatabase, :type => "void ()"
    publish :function => :RequiredPackages, :type => "list <string> (string)"
    publish :function => :RequiredPackagesToInstall, :type => "list <string> (string)"
    publish :function => :RequiredPackagesToInstallSummary, :type => "string (string)"
    publish :function => :Read, :type => "boolean (boolean)"
    publish :function => :ExportVolumeSettings, :type => "list <list <map>> (list <list <list>>)"
    publish :function => :ImportVolumeSettings, :type => "list <list <list>> (list)"
    publish :function => :Set, :type => "void (map)"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Export, :type => "map ()"
    publish :function => :RequiredKernelModules, :type => "list <string> ()"
    publish :function => :AllRequiredPackagesInstalled, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Summary, :type => "string ()"
    publish :function => :CollectOptions, :type => "map (string)"
    publish :function => :ForceReset, :type => "void ()"
    publish :function => :Propose, :type => "boolean ()"
    publish :function => :StoreSettings, :type => "void ()"
    publish :function => :RestoreSettings, :type => "void ()"
    publish :function => :Changed, :type => "boolean ()"
    publish :function => :GetSoundCardList, :type => "list ()"
    publish :function => :StoreUniqueKeys, :type => "void ()"
    publish :function => :GetJoystickSettings, :type => "map (string)"
    publish :function => :StoreMixer, :type => "void ()"
    publish :function => :SetVolume, :type => "boolean (integer, string, integer)"
    publish :function => :InitMixer, :type => "void (integer, string)"
    publish :function => :HasJoystick, :type => "boolean (integer)"
    publish :function => :GetSoundCardListWithJoy, :type => "list ()"
    publish :function => :SetConfirmPackages, :type => "void (boolean)"
    publish :function => :ConfirmPackages, :type => "boolean ()"
  end

  Sound = SoundClass.new
  Sound.main
end
