#
# Makefile.am for modules/y2c_snd/src
#

menudir = $(YAST2DIR)/menuentries
modulesdir = $(YAST2DIR)/clients
includedir = $(YAST2DIR)/include/sound
bindir = $(YAST2DIR)/bin

include_DATA = \
	routines.ycp \
	write_routines.ycp \
	read_routines.ycp \
	alsa_routines.ycp \
	ui.ycp \
	texts.ycp \
	card_wizard.ycp 


modules_DATA = 	\
	sound.ycp 		\
	sound_manual.ycp	\
	sound_write.ycp		\
	sound_complex.ycp	\
	sound_options.ycp	\
	sound_volume.ycp     	\
	sound_select.ycp	\
	sound_summary.ycp

menu_DATA = menuentry_sound.ycp

bin_SCRIPTS = copyfonts

EXTRA_DIST = \
	$(modules_DATA) \
	$(menu_DATA) \
	$(include_DATA) \
	$(bin_SCRIPTS)
