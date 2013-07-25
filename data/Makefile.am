#
# Makefile.am for sound/data
#

SUBDIRS = doc

ydata_DATA = alsa_packages.ycp sndcards.ycp

sound_db_generator = alsa_drivers.rb data_cards.rb data_joystick.rb data_mixer.rb data_extra_ids.rb generate_soundcard_db.rb sound_db_generator.rb ycp_format.rb

sndcards.ycp: $(sound_db_generator)
	./generate_soundcard_db.rb > sndcards.ycp
# verify the validity (syntax check)
	ycpc -E -q sndcards.ycp

CLEANFILES = sndcards.ycp

EXTRA_DIST = alsa_packages.ycp $(sound_db_generator)
