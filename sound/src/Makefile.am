#
# Makefile.am for modules/y2c_snd/src
#

clientsdir = $(YAST2DIR)/clients
yincludedir = $(YAST2DIR)/include/sound
modulesdir = $(YAST2DIR)/modules
bindir = $(YAST2DIR)/bin

yinclude_DATA = \
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
	manual.ycp \
	joy_dialog.ycp\
	joysticks.ycp


clients_DATA = 	\
	sound.ycp 		\
	sound_write.ycp		\
	sound_summary.ycp	\
	sound_auto.ycp		\
	joystick.ycp		\
	proposal_sound.ycp

config_DATA = \
	sound.y2cc \
	joystick.y2cc

modules_DATA = Sound.ycp	\
	Joystick.ycp

bin_SCRIPTS = copyfonts

EXTRA_DIST = $(modules_DATA) $(config_DATA) $(yinclude_DATA) $(bin_SCRIPTS) $(clients_DATA) 
