#
# Makefile.am for y2c_snd/doc/autodoc
#
# $Id$
#


docdir = @DOCDIR@
htmldir = $(docdir)/autodocs

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

html_DATA = index.html $(wildcard *.html)

index.html: $(ycp_files)
	@YAST2DIR@/bin/ycpdoc -d. $(ycp_files)

CLEANFILES = $(html_DATA)
