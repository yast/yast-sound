# encoding: utf-8

# File:
#   mixer.ycp
#
# Module:
#   Sound
#
# Summary:
#   advanced dialog for mixer setting
#
# Authors:
# Dan Meszaros <dmeszar@suse.cz>
#
# String corrections by Christian Steinruecken <cstein@suse.de>, 2001/08/01
#
#
module Yast
  module SoundMixerInclude
    def initialize_sound_mixer(include_target)
      Yast.import "UI"
      textdomain "sound"
      Yast.import "Wizard"
      Yast.import "Sound"
      Yast.import "Label"

      Yast.include include_target, "sound/ui.rb"
      Yast.include include_target, "sound/volume_routines.rb"

      # translation map of channel names
      @channel_trans = {
        # channel name - label for IntField widget in mixer dialog
        "Master"        => _(
          "Master"
        ),
        # channel name - label for IntField widget in mixer dialog
        "PCM"           => _(
          "PCM"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Master Mono"   => _(
          "Master Mono"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Headphone"     => _(
          "Headphone"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Line"          => _(
          "Line"
        ),
        # channel name - label for IntField widget in mixer dialog
        "CD"            => _(
          "CD"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Mic"           => _(
          "Mic"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Video"         => _(
          "Video"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Phone"         => _(
          "Phone"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Aux"           => _(
          "Aux"
        ),
        # channel name - label for IntField widget in mixer dialog
        "PC Speaker"    => _(
          "PC Speaker"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Bass"          => _(
          "Bass"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Treble"        => _(
          "Treble"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Surround"      => _(
          "Surround"
        ),
        # channel name - label for IntField widget in mixer dialog
        "LFE"           => _(
          "LFE"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Center"        => _(
          "Center"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Wave"          => _(
          "Wave"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Wave Center"   => _(
          "Wave Center"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Wave Surround" => _(
          "Wave Surround"
        ),
        # channel name - label for IntField widget in mixer dialog
        "AC97"          => _(
          "AC97"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Music"         => _(
          "Music"
        ),
        # channel name - label for IntField widget in mixer dialog
        "Front"         => _(
          "Front"
        ),
        # channel name - label for IntField widget in mixer dialog
        "iSpeaker"      => _(
          "iSpeaker"
        )
      }
    end

    # Translate channel name
    # @param [String] name untranslated channel name
    # @return [String] translated name
    def translateChannelName(name)
      return "" if name == nil || name == ""

      ret = Ops.get_string(@channel_trans, name, name)
      Builtins.y2debug("translated channel name: %1", ret)

      ret
    end

    # returns intfield (if we are running in ncurses) or
    # slider (for qt)
    # @param label label for slider
    # @param [Fixnum] value initial value
    # @param [Boolean] spec true-slider false-intfield
    # @return [Yast::Term] widget
    def volElement(channel_id, value, spec)
      label = channel_id

      # remove the index from the channel ID if it's there
      if Builtins.regexpmatch(channel_id, "^.*_#[0-9]+\#$")
        label = Builtins.regexpsub(channel_id, "^(.*)_#[0-9]+\#$", "\\1")
        index_str = Builtins.regexpsub(channel_id, "^.*_#([0-9]+)\#$", "\\1")
        index = Builtins.tointeger(index_str)

        if index != nil
          # add index + 1 to the channel label
          # so there are channels "Speaker", "Speaker 2", "Speaker 3", ...
          label = Builtins.sformat("%1 %2", label, Ops.add(index, 1))
        end
      end

      if UI.HasSpecialWidget(:Slider)
        return Slider(
          Id(channel_id),
          Opt(:notify),
          translateChannelName(label),
          0,
          100,
          value
        )
      else
        return IntField(
          Id(channel_id),
          Opt(:notify),
          translateChannelName(label),
          0,
          100,
          value
        )
      end
    end

    # creates a mixer widget with channels obtained from 1st param
    # @param [Array] channels channels to be shown
    # @return [Yast::Term] widget
    def mixerWidget(channels)
      channels = deep_copy(channels)
      widget = VBox()
      spec = UI.HasSpecialWidget(:Slider)
      nchan = Ops.subtract(Builtins.size(channels), 2) # don't count in 'Master' and 'PCM'
      ncols = 3

      # how many channels per column
      chansPerCol = Builtins.tointeger(
        Ops.add(
          Ops.divide(Builtins.tofloat(nchan), Builtins.tofloat(ncols)),
          0.999
        )
      )

      # 1. group first two elements to one Frame
      ttmp = nil
      if spec
        ttmp = VBox()
      else
        ttmp = HBox()
      end
      pos = 0
      while Ops.less_than(pos, 2) && Ops.less_than(pos, Builtins.size(channels))
        lab = Ops.get_string(channels, [pos, 0], "")
        vol = Ops.get_integer(channels, [pos, 1], 0)
        ttmp = Builtins.add(ttmp, volElement(lab, vol, spec))
        pos = Ops.add(pos, 1)
      end

      ttmp = Builtins.add(ttmp, VSpacing(1))

      # frame label
      mainGroup = Frame(
        _("&Master volume"),
        HBox(
          HSpacing(3),
          ttmp,
          HSpacing(3),
          VBox(
            # push button label
            PushButton(Id(:test), Opt(:key_F6), _("&Test"))
          )
        )
      )

      # 2. now group elements to columns

      counter = 0
      col = HBox(HSpacing(2))

      while Ops.less_than(pos, Builtins.size(channels))
        if ncols == counter
          widget = Builtins.add(widget, Top(col))
          widget = Builtins.add(widget, HStretch()) if !spec
          col = HBox(HSpacing(2))
          counter = 0
        end

        lab = Ops.get_string(channels, [pos, 0], "")
        vol = Ops.get_integer(channels, [pos, 1], 0)

        col = Builtins.add(col, HWeight(1, volElement(lab, vol, false)))
        col = Builtins.add(col, HSpacing(2))
        pos = Ops.add(pos, 1)
        counter = Ops.add(counter, 1)
      end

      while Ops.less_than(counter, ncols)
        col = Builtins.add(col, HWeight(1, Label(" ")))
        col = Builtins.add(col, HSpacing(2))
        counter = Ops.add(counter, 1)
      end
      widget = Builtins.add(widget, Top(col))

      # frame label
      VBox(mainGroup, Frame(_("&Other channels"), widget))
    end

    # shows mixer dialog for respective card
    # @param [Fixnum] card_id card id
    # @return [Hash] result
    def mixerDialog(card_id)
      Sound.LoadDatabase(true)

      pth = Builtins.topath(
        Builtins.sformat(".audio.alsa.cards.%1.channels", card_id)
      )
      channels = []
      modname = ""
      # card name
      model = Ops.get_locale(
        Sound.modules_conf,
        [card_id, "model"],
        _("Unknown")
      )

      if Sound.use_alsa
        modname = Ops.get_string(
          Sound.modules_conf,
          [card_id, "module"],
          "snd-dummy"
        )
        channels = Convert.convert(
          Ops.get(Sound.db_modules, [modname, "mixer_elements"], SCR.Dir(pth)),
          :from => "any",
          :to   => "list <string>"
        )
      else
        channels = ["Master"]
      end

      muted = []

      pth = Builtins.topath(
        Builtins.sformat(".audio.alsa.cards.%1.name", card_id)
      )
      card_name = Sound.use_alsa ?
        Convert.to_string(SCR.Read(pth)) :
        Builtins.sformat("%1", card_id)

      # get list of muted channels
      if Sound.use_alsa
        Builtins.foreach(
          Convert.convert(channels, :from => "list", :to => "list <string>")
        ) do |channel|
          pth2 = Builtins.topath(
            Builtins.sformat(
              ".audio.alsa.cards.%1.channels.%2.mute",
              card_id,
              channel
            )
          )
          if Convert.to_boolean(SCR.Read(pth2))
            muted = Builtins.add(muted, channel)
          end
        end

        Builtins.y2debug("muted: %1", muted)

        # put 'Master', 'PCM' to list head
        if Builtins.contains(channels, "PCM")
          channels = Builtins.filter(
            Convert.convert(channels, :from => "list", :to => "list <string>")
          ) { |ch| ch != "PCM" }
          channels = Builtins.prepend(channels, "PCM")
        end

        master_channel = Ops.get_string(
          Sound.db_modules,
          [modname, "main_volume"],
          "Master"
        )

        if modname != "" && Builtins.contains(channels, master_channel)
          channels = Builtins.filter(
            Convert.convert(channels, :from => "list", :to => "list <string>")
          ) { |ch| ch != master_channel }
          channels = Builtins.prepend(channels, master_channel)
        end
        channels = Builtins.maplist(
          Convert.convert(channels, :from => "list", :to => "list <string>")
        ) do |ch|
          if Builtins.contains(muted, ch)
            next [ch, 0]
          else
            next [
              ch,
              SCR.Read(
                Builtins.topath(
                  Builtins.sformat(
                    ".audio.alsa.cards.%1.channels.%2.volume",
                    card_id,
                    ch
                  )
                )
              )
            ]
          end
        end
      else
        vol = Convert.to_integer(
          SCR.Read(
            Builtins.topath(
              Builtins.sformat(".audio.oss.cards.%1.channels.Master", card_id)
            )
          )
        )
        channels = [["Master", vol]]
      end

      # help text - mixer setting
      help = _(
        "<P>With this dialog you can set volume for each channel of the selected sound card. \nPress <B>Next</B> to save your volume settings, press <B>Back</B> to restore the original settings.</P>"
      )

      con = mixerWidget(channels)

      # dialog header, %1 = card id (number), %2 = name
      Wizard.SetContentsButtons(
        Builtins.sformat(_("Volume Settings for Card %1 - %2"), card_id, model),
        con,
        help,
        Label.BackButton,
        Label.OKButton
      )

      ui = nil # value can be `next `abort... or string (channel name)

      UI.ChangeWidget(Id(:test), :Enabled, !Mode.config)
      begin
        ui = UI.UserInput

        if Ops.is_string?(ui)
          # unmute if neccessary
          if Builtins.contains(muted, ui)
            SCR.Write(
              Builtins.topath(
                Builtins.sformat(
                  ".audio.alsa.cards.%1.channels.%2.mute",
                  card_id,
                  ui
                )
              ),
              false
            )
          end
          # set volume
          if Sound.use_alsa
            setVolume(
              Convert.to_string(ui),
              card_id,
              Convert.to_integer(UI.QueryWidget(Id(ui), :Value))
            )
          else
            setVolume(
              "Master",
              card_id,
              Convert.to_integer(UI.QueryWidget(Id(ui), :Value))
            )
          end
        elsif ui == :test
          PlayTest(card_id)
        elsif (ui == :abort || ui == :cancel) && ReallyAbort()
          return { "ui" => :abort }
        end
      end until ui == :back || ui == :next

      if ui == :next
        # store volume settings
        pth2 = Builtins.topath(
          Builtins.sformat(".audio.alsa.cards.%1.store", card_id)
        )
        SCR.Execute(pth2, 0, 0)
      else
        # restore volume settings
        pth2 = Builtins.topath(
          Builtins.sformat(".audio.alsa.cards.%1.restore", card_id)
        )
        SCR.Execute(pth2, 0, 0)
      end

      { "ui" => ui }
    end
  end
end
