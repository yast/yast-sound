# encoding: utf-8

# File:
#   sound_write.ycp
#
# Module:
#   Sound
#
# Summary:
#   Provides saving /etc/modules.conf and volume.
#
# Authors:
#   Dan Vesely <dan@suse.cz>
#   Dan Meszaros <dmeszar@suse.cz>
#
#
# Parameters are given in a map with keys:
#         "modules_conf" ... save info- list of configured cards:
#	   [
#		$[
#		    "model"	: "sb live!",
#		    "alias"	: "snd-card-0",
#		    "options"	: $["snd_id":"0" ...],
#		    "module"	: "snd-emu10k1",
#		    "unique_key": "abcd.efghijklmn"
#                  "bus"       : "pci",
#                  "bus_id"    : "0000:00:07.0"
#		],
#              $[
#                  "model"     : "avi onboard!",
#                  "alias"     : "snd-card-1",
#                  "options"   : $["snd_id":"1" ...],
#                  "module"    : "snd-asf",
#                  "unique_key": "abcd.abcdefghij"
#                  "bus"       : "pci",
#                  "bus_id"    : "0000:00:03.1"
#              ]
#         ]
#
#	   "rc_vars" ... sysconfig values
#	   $[
#		"LOAD_SEQUENCER" : "yes"
#         ]
#
#	   "vol_settings" ... volume setting (usefull only for autoconfig)
#	   [
#		[  // card #1
#		    ["PCM", 32, false], ["Master", 100, true] ...
#	        ],
#		[  // card #2
#		],
#		...
#
#	   ]
#
# Steps:
#        1. save '/etc/modules.conf'
#        2. save '/etc/rc.config'
#        3. save volume
#        4. call function to provide some additional work
#
# Return boolean true on success, false if failed
module Yast
  class SoundWriteClient < Client
    def main
      Yast.import "UI"
      textdomain "sound"


      Yast.include self, "sound/write_routines.rb"

      Yast.import "Progress"
      Yast.import "Wizard"
      Yast.import "Service"
      Yast.import "Package"
      Yast.import "Mode"
      Yast.import "Report"
      Yast.import "Directory"

      Yast.import "Sound"
      Yast.import "Joystick"

      @joy_cmd = Ops.add(Directory.bindir, "/joystickdrivers")
      @alsa_cmd = Ops.add(Directory.bindir, "/alsadrivers")

      # ==== MAIN ====

      @settings = Convert.to_map(WFM.Args(0))
      @rc_values = Ops.get_map(@settings, "rc_vars", {})
      @save_info = Ops.get_list(@settings, "modules_conf", [])
      @vol_settings = Ops.get_list(@settings, "volume_settings", [])

      # do nothing when proposal is empty
      # (Sound::installation is set to true in proposal mode)
      if Sound.installation && Builtins.size(@save_info) == 0
        Builtins.y2debug("empty proposal. exiting.")
        return true
      end

      @install = !Sound.AllRequiredPackagesInstalled

      @stones = [
        # progress bar item
        _("Save module configuration"),
        # progress bar item
        _("Save sound card information"),
        # progress bar item
        _("Save sysconfig values"),
        # progress bar item
        _("Start sound card"),
        # progress bar item
        _("Store volume"),
        # progress bar item
        _("Store joystick settings")
      ]

      @stones2 = [
        # progress bar item
        _("Saving sound card settings..."),
        # progress bar item
        _("Saving card information..."),
        # progress bar item
        _("Saving sysconfig values..."),
        # progress bar item
        _("Starting sound card..."),
        # progress bar item
        _("Storing volume settings..."),
        # progress bar item
        _("Storing joystick settings...")
      ]

      if @install && !Mode.autoinst
        # progress bar item
        @stones = Builtins.add(@stones, _("Install required packages"))

        # progress bar item
        @stones2 = Builtins.add(@stones2, _("Installing required packages..."))
      end


      # not really necessary for Progress stuf (it is set off in _auto client)
      if !Sound.write_only
        # progres bar label
        Progress.New(
          _("Saving sound card settings..."),
          " ",
          Ops.subtract(Builtins.size(@stones), 1),
          # progres bar label
          @stones,
          @stones2,
          _("Saving sound card settings...")
        )
        Wizard.DisableAbortButton if Sound.use_ui
      end

      Progress.NextStage

      @reqmodules = []

      # in autoyast installation the packages are installed by autoyast
      # see sound_auto.ycp - it's called with "Packages" argument
      if !Mode.autoinst
        # get required sound and joystick kernel modules
        @reqmodules = Sound.RequiredKernelModules
        @reqjoymodules = Joystick.RequiredKernelModules

        @reqmodules = [] if @reqmodules == nil

        @reqjoymodules = [] if @reqjoymodules == nil

        # merge lists, remove duplicates
        @reqmodules = Convert.convert(
          Builtins.union(@reqmodules, @reqjoymodules),
          :from => "list",
          :to   => "list <string>"
        )

        if Ops.greater_than(Builtins.size(@reqmodules), 0)
          # ensure that all required kernel modules are installed
          Package.InstallKernel(@reqmodules)
        end
      end

      # save config to /etc/modprobe.d/50-sound.conf
      SaveModulesEntry(@save_info, [])

      Builtins.sleep(10)
      Progress.NextStage

      Sound.StoreUniqueKeys

      Builtins.sleep(10)
      Progress.NextStage

      SaveRCValues(@rc_values)

      Builtins.y2milestone("Sound::write_only: %1", Sound.write_only)

      Builtins.sleep(10)
      Progress.NextStage


      @configuredcards = Sound.GetSoundCardList
      if !Sound.write_only
        # stop joystick before restarting ALSA
        @cmd = Ops.add(@joy_cmd, " unload")
        Builtins.y2milestone("Executing: %1", @cmd)
        SCR.Execute(path(".target.bash"), @cmd)

        # restart ALSA
        if Ops.greater_than(Builtins.size(@configuredcards), 0)
          @cmd = Ops.add(@alsa_cmd, " reload")
          Builtins.y2milestone("Executing: %1", @cmd)
          SCR.Execute(path(".target.bash"), @cmd)
        end
      end

      Progress.NextStage

      # initialize mixer settings
      if Mode.installation ||
          SCR.Read(path(".target.size"), Sound.asound_state) == -1 ||
          Sound.write_only
        @i = 0
        Builtins.maplist(
          Convert.convert(@save_info, :from => "list", :to => "list <map>")
        ) do |e|
          Sound.InitMixer(@i, Ops.get_string(e, "module", ""))
          @i = Ops.add(@i, 1)
        end
        Builtins.y2milestone("Mixer is initialized")
      else
        Builtins.y2milestone("Mixer was not initialized during saving")
      end

      if Ops.greater_than(Builtins.size(@configuredcards), 0)
        logmixer("Mixer status before saving the volume")
        Builtins.y2milestone("volume_settings: %1", Sound.volume_settings)

        SaveVolume()
        logmixer("Mixer status after saving the volume")

        if Sound.write_only && Builtins.haskey(@settings, "volume_settings")
          set_vol_settings(@vol_settings)
        end
      end

      Builtins.sleep(10)
      Progress.NextStage

      # abort block for read/write dialogs
      @abort_block = lambda { false }

      # write joystick configuration
      Joystick.Write(@abort_block)

      if @install && !Mode.autoinst
        Progress.NextStage
        install_packages(@reqmodules)
      end

      if Ops.greater_than(Builtins.size(@configuredcards), 0)
        # enable alsasound service in runlevels 2,3,5
        Service.Finetune("alsasound", ["2", "3", "5"])
      else
        # disable sound service - it's not needed, no soundcard is present
        Service.Adjust("joystick", "disable")
        Service.Adjust("alsasound", "disable")
      end

      true # TODO return value!
    end

    def logmixer(_when)
      # log mixer settings
      Builtins.y2milestone(
        "Mixer (%1): %2",
        _when,
        SCR.Execute(path(".target.bash_output"), "/usr/bin/amixer")
      )
      Builtins.y2milestone("volume_settings: %1", Sound.volume_settings)
      Builtins.y2milestone(
        "asound size: %1",
        SCR.Read(path(".target.size"), Sound.asound_state)
      )

      nil
    end

    def install_packages(modules)
      modules = deep_copy(modules)
      packages_to_install = []

      Builtins.foreach(modules) do |driver|
        req_packages = Sound.RequiredPackagesToInstall(driver)
        packages_to_install = Convert.convert(
          Builtins.union(packages_to_install, req_packages),
          :from => "list",
          :to   => "list <string>"
        )
      end 


      Builtins.y2milestone(
        "Collected packages to install: %1",
        packages_to_install
      )

      if Ops.greater_than(Builtins.size(packages_to_install), 0)
        not_available = []

        Builtins.foreach(packages_to_install) do |pkg|
          avail = Package.Available(pkg)
          not_available = Builtins.add(not_available, pkg) if !avail
        end 


        if Ops.greater_than(Builtins.size(not_available), 0)
          Report.Error(
            Builtins.sformat(
              _(
                "These required packages are not available: %1\n" +
                  "Some sound devices may not work or some features may not be supported.\n" +
                  "\n" +
                  "Enable or add an additional software repository containing the packages.\n"
              ),
              Builtins.mergestring(not_available, ", ")
            )
          )
          return false
        end

        if Sound.ConfirmPackages
          return Package.InstallAll(packages_to_install)
        else
          # do not ask the user, install the packages immediately
          return Package.DoInstall(packages_to_install)
        end
      end

      true
    end
  end
end

Yast::SoundWriteClient.new.main
