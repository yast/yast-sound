# encoding: utf-8

# File:
#   volume_routines.ycp
#
# Module:
#   Sound
#
# Summary:
#   Routines for sound card volume settings
#
# Authors:
#	Dan Vesely <dan@suse.cz>
#	Dan Meszaros <dmeszar@suse.cz>
#	Jiri Suchomel <jsuchome@suse.cz>
#
module Yast
  module SoundVolumeRoutinesInclude
    def initialize_sound_volume_routines(include_target)
      Yast.import "Arch"
      Yast.import "Sound"
      Yast.import "Directory"
      Yast.import "Mode"
      Yast.import "Popup"

      textdomain "sound"
    end

    # sets volume in percents (0..100) for given card and card_id
    # @param [String] group channel
    # @param [Fixnum] cardid card id
    # @param [Fixnum] value volume 0-100
    # @return [Boolean] success/failure
    def setVolume(group, cardid, value)
      Builtins.y2debug(
        "setVolume(group: %1, cardid: %2, value: %3",
        group,
        cardid,
        value
      )

      if !Sound.use_alsa
        if Arch.sparc
          cmd = Builtins.sformat(
            "/usr/bin/aumix -d /dev/mixer%1 -w %2",
            cardid,
            value
          )
          SCR.Execute(path(".target.bash"), cmd, {})
        else
          p = Builtins.sformat(".audio.oss.cards.%1.channels.%2", cardid, group)
          SCR.Write(Builtins.topath(p), value)
        end
        return true
      end

      # rest is for ALSA
      # In Mode::autoinst(), we need to update volume_settings from
      # UpdateCardsToTargetSystem functions; volume will be saved later
      # in set_vol_settings ().
      if !Mode.config && !Mode.autoinst
        p = Builtins.sformat(
          ".audio.alsa.cards.%1.channels.%2.volume",
          cardid,
          group
        )
        return SCR.Write(Builtins.topath(p), value)
      else
        tmp = Ops.get(Sound.volume_settings, cardid, [])

        found = false
        updated_channels = []
        Builtins.foreach(tmp) do |ch|
          new_ch = deep_copy(ch)
          if Ops.get_string(new_ch, 0, "") == group
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
          tmp = Builtins.add(tmp, [group, value, false])
        end

        Ops.set(Sound.volume_settings, cardid, tmp)

        return true
      end
    end

    # stores the volume to file. stored volume will be restored after reboot
    # (ALSA only)
    # @param [Fixnum] card_id card id
    # @return [Boolean] success/failure
    def storeVolume(card_id)
      SCR.Execute(path(".audio.alsa.store"), 0, 0) if card_id == -1
      p = Builtins.sformat(".audio.alsa.cards.%1.store", card_id)

      Convert.to_boolean(SCR.Execute(Builtins.topath(p), 0, 0))
    end


    # plays test sound to card #card_id
    # @param [Fixnum] card_id card id
    # @return [String] with error message. empty on success
    def PlayTest(card_id)
      fname = "/usr/share/sounds/alsa/test.wav"
      fname = "/usr/share/sounds/test.mp3" if !Sound.use_alsa
      if SCR.Read(path(".target.size"), fname) == -1
        # popup message: test audio file was not found
        return Builtins.sformat(
          _("Cannot find file:\n%1\n(test audio file)"),
          fname
        )
      end

      command = !Sound.use_alsa ?
        Builtins.sformat("/usr/bin/mpg123 -a /dev/dsp%1 %2", card_id, fname) :
        # unset ALSA_CONFIG_PATH (bnc#440981)
        Builtins.sformat(
          "ALSA_CONFIG_PATH= /usr/bin/aplay -q -N -D default:%1 %2 > /dev/null 2>&1",
          card_id,
          fname
        )

      Builtins.y2milestone("Executing: %1", command)

      SCR.Execute(path(".target.bash_background"), command)

      ""
    end


    # sound_start_tmp starts alsa using temporary modules.conf
    # @param [Boolean] restore true - call alsactl restore, false - don't
    # @return [void]
    def sound_start_tmp(restore)
      ret = true

      # get the list of commands needed for start
      cmds = Sound.CreateModprobeCommands
      Builtins.y2milestone("modprobe commands: %1", cmds)

      snd = Builtins.sformat(
        "/sbin/modprobe snd cards_limit=%1 major=116",
        Builtins.size(Sound.modules_conf)
      )

      if !Sound.use_alsa
        snd = Builtins.sformat(
          "/sbin/modprobe snd snd_cards_limit=%1 snd_major=116",
          Builtins.size(Sound.modules_conf)
        ) 
        #FIXME parameter names for OSS?
      end

      # start 'snd' module first
      cmds = Builtins.flatten([[snd], cmds])
      Builtins.maplist(
        Convert.convert(cmds, :from => "list", :to => "list <string>")
      ) do |cmd|
        res = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd, {}))
        if Ops.get_string(res, "stderr", "") != ""
          Builtins.y2error(
            Ops.add(
              "/sbin/modprobe error output: \n",
              Ops.get_string(res, "stderr", "")
            )
          )
          ret = false
        end
      end

      ret
    end

    # removes all sound modules from kernel
    # @return [void]
    def sound_stop
      if Sound.use_alsa
        cmd = Ops.add(Directory.bindir, "/alsadrivers unload")
        Builtins.y2milestone("Executing: %1", cmd)
        SCR.Execute(path(".target.bash"), cmd)

        aoa_used = false
        Builtins.foreach(Sound.modules_conf) do |card|
          aoa_used = true if Ops.get_string(card, "module", "") == "snd-aoa"
        end 


        if aoa_used
          # unload the extra module
          Builtins.y2milestone("Unloading snd-aoa-i2sbus driver")
          SCR.Execute(path(".target.bash"), "/sbin/rmmod snd-aoa-i2sbus")
          SCR.Execute(path(".target.bash"), "/sbin/rmmod snd-aoa-fabric-layout")
        end
      else
        mods = SCR.Dir(path(".modinfo.kernel.sound.oss"))
        mods = Builtins.add(mods, "emu10k1")
        mods = Builtins.add(mods, "cs4281")
        modules = Convert.to_map(SCR.Read(path(".proc.modules")))
        Builtins.foreach(
          Convert.convert(mods, :from => "list", :to => "list <string>")
        ) do |mod|
          if Builtins.haskey(modules, mod)
            SCR.Execute(
              path(".target.bash"),
              Builtins.sformat("/sbin/rmmod -r %1", mod)
            )
          end
        end
      end

      nil
    end

    def GlobExists(glob)
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("echo -n %1", glob)
        )
      )
      Builtins.y2debug("output: %1", out)

      Ops.get_string(out, "stdout", "") != glob
    end

    # stops all programs using sound devices
    # @return [Boolean] true if nothing's using sound, false otherwise
    def stop_programs
      return true if Mode.config || Mode.autoinst

      # list of files to check, * must be present!
      audio_files = [
        "/dev/dsp*",
        "/dev/audio*",
        "/dev/mixer*",
        "/dev/midi*",
        "/dev/mixer*"
      ]

      audio_files = Builtins.filter(audio_files) { |file| GlobExists(file) }
      Builtins.y2milestone("Checking audio files: %1", audio_files)

      if Builtins.size(audio_files) == 0
        Builtins.y2milestone("No audio device file found, skipping fuser call")
        return true
      end

      fuser_options = Builtins.mergestring(audio_files, " ")
      Builtins.y2milestone("fuser options: %1", fuser_options)

      fuser = Convert.to_integer(
        SCR.Execute(
          path(".target.bash"),
          Ops.add("/bin/fuser ", fuser_options),
          {}
        )
      )

      if fuser == 0
        msg = Ops.get_string(Sound.STRINGS, "WhichDialogMsg", "")
        terminate = Sound.use_ui ? Popup.YesNo(msg) : true
        if terminate
          SCR.Execute(
            path(".target.bash"),
            Ops.add("/bin/fuser -k ", fuser_options),
            {}
          )
        else
          return false
        end
      end
      true
    end
  end
end
