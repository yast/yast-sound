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
	../../src/routines.ycp \
	../../src/sound_write.ycp \
	../../src/texts.ycp \
	../../src/ui.ycp \
	../../src/sound_volume.ycp \
	../../src/write_routines.ycp

all: $(ycp_files)
	ycpdoc -d. $(ycp_files)

clean:
	rm -f *~ *.html
