#
# Makefile.am for y2c_snd/doc/autodoc
#
# $Id$
#


docdir = @DOCDIR@
htmldir = $(docdir)/autodocs

ycp_files = \
	../../src/menuentry_sound.y2cc \
	../../src/sound.ycp \
	../../src/complex.ycp \
	../../src/manual.ycp \
	../../src/options.ycp \
	../../src/routines.ycp \
	../../src/sound_write.ycp \
	../../src/texts.ycp \
	../../src/ui.ycp \
	../../src/volume.ycp \
	../../src/write_routines.ycp \
	../../src/mixer.ycp \
	../../src/oss_routines.ycp \
	../../src/alsa_routines.ycp \
	../../src/read_routines.ycp

html_DATA = index.html $(wildcard *.html)

index.html: $(ycp_files)
	@YAST2DIR@/bin/ycpdoc -d. $(ycp_files)

CLEANFILES = $(html_DATA)
