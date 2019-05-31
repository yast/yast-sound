# Sources for sound

module_DATA = \
  modules/PulseAudio.rb \
  modules/Sound.rb

client_DATA = \
  clients/sound_write.rb \
  clients/sound_summary.rb \
  clients/sound_proposal.rb \
  clients/sound.rb \
  clients/sound_auto.rb

yncludedir = @yncludedir@/sound
ynclude_DATA = \
  include/sound/card_wizard.rb \
  include/sound/write_routines.rb \
  include/sound/wizards.rb \
  include/sound/options.rb \
  include/sound/ui.rb \
  include/sound/volume.rb \
  include/sound/manual.rb \
  include/sound/read_routines.rb \
  include/sound/volume_routines.rb \
  include/sound/mixer.rb \
  include/sound/complex.rb \
  include/sound/routines.rb \
  include/sound/texts.rb

scrconf_DATA = \
  scrconf/cfg_sound.scr \
  scrconf/modprobe_sound.scr

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/sound.rnc

ybin_SCRIPTS = \
  bin/alsadrivers \
  bin/copyfonts

ydata_DATA = \
  data/alsa_packages.yml

desktop_DATA = \
  desktop/org.openSUSE.YaST.Sound.desktop

scalabledir = @icondir@/hicolor/scalable/apps
scalable_DATA = \
  icons/hicolor/scalable/apps/yast-sound.svg

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(schemafiles_DATA) $(ybin_SCRIPTS) $(ydata_DATA) $(desktop_DATA) $(scalable_DATA)

include $(top_srcdir)/Makefile.am.common
