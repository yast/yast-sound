#
# Makefile.am for modules/y2c_snd/src
#

menudir = $(YAST2DIR)/menuentries
clientsdir = $(YAST2DIR)/clients
includedir = $(YAST2DIR)/include/sound
modulesdir = $(YAST2DIR)/modules
bindir = $(YAST2DIR)/bin

include_DATA = \
	routines.ycp \
	write_routines.ycp \
	read_routines.ycp \
	alsa_routines.ycp \
	oss_routines.ycp \
	ui.ycp \
	texts.ycp \
	card_wizard.ycp \
	mixer.ycp \
	volume.ycp \
	options.ycp \
	complex.ycp \
	select.ycp \
	manual.ycp


clients_DATA = 	\
	sound.ycp 		\
	sound_write.ycp		\
	sound_summary.ycp	\
	sound_auto.ycp

menu_DATA = menuentry_sound.y2cc

modules_DATA = Sound.ycp

bin_SCRIPTS = copyfonts

EXTRA_DIST = $(modules_DATA) $(menu_DATA) $(include_DATA) $(bin_SCRIPTS) $(clients_DATA)
