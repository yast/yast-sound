#
# Makefile.am for sound/sound/src
#

yncludedir = @yncludedir@/sound

ynclude_DATA = \
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


client_DATA = 	\
	sound.ycp 		\
	sound_write.ycp		\
	sound_summary.ycp	\
	sound_auto.ycp		\
	joystick.ycp		\
	sound_proposal.ycp

config_DATA = \
	sound.y2cc \
	joystick.y2cc

module_DATA = Sound.ycp	\
	Joystick.ycp

ybin_SCRIPTS = copyfonts

EXTRA_DIST = $(module_DATA) $(config_DATA) $(ynclude_DATA) $(ybin_SCRIPTS) $(client_DATA) 
