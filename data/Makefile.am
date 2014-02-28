#
# Makefile.am for sound/data
#

SUBDIRS = doc

ydata_DATA = sndcards.yml

sound_db_generator = alsa_drivers.rb generate_soundcard_db.rb sound_db_generator.rb data_cards.yml data_extra_id.yml data_mixer.yml

sndcards.yml: $(sound_db_generator)
	./generate_soundcard_db.rb > sndcards.yml

CLEANFILES = sndcards.yml

EXTRA_DIST = $(sound_db_generator)

