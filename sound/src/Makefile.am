#
# Makefile.am for modules/y2c_snd/src
#

menudir = $(YAST2DIR)/menuentries
modulesdir = $(YAST2DIR)/clients
includedir = $(YAST2DIR)/include/sound

include_DATA = \
	sound_routines.ycp \
	sound_ui.ycp

modules_DATA = 	\
	sound.ycp 		\
	sound_manual.ycp	\
	sound_save.ycp		\
	sound_complex.ycp	\
	sound_options.ycp	\
	sound_volume.ycp     	\
	sound_texts.ycp

menu_DATA = menuentry_sound.ycp

EXTRA_DIST = \
	$(modules_DATA) \
	$(menu_DATA) \
	$(include_DATA)
