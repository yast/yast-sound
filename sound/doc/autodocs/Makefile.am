#
# Makefile.am for y2c_snd/doc/autodoc
#
# $Id$
#


docdir = @DOCDIR@
htmldir = $(docdir)/y2c_snd/autodocs

ycp_files = \
	../../src/menuentry_sound.ycp \
	../../src/sound.ycp \
	../../src/sound_complex.ycp \
	../../src/sound_manual.ycp \
	../../src/sound_options.ycp \
	../../src/sound_routines.ycp \
	../../src/sound_save.ycp \
	../../src/sound_texts.ycp \
	../../src/sound_ui.ycp \
	../../src/sound_volume.ycp

all: $(ycp_files)
	@YAST2DIR@/bin/ycpdoc -d. $(ycp_files)

clean:
	rm -f *~ *.html
