#
# Makefile.am for y2c_snd/doc/autodocs
#
# $Id$
#

docdir = @DOCDIR@
htmldir = $(docdir)/y2c_lan/autodocs

ycp_files = \
	../../src/sound.ycp 		\
	../../src/sound_complex.ycp	\
	../../src/sound_manual.ycp	\
	../../src/sound_options.ycp	\
	../../src/sound_routines.ycp	\
	../../src/sound_save.ycp	\
	../../src/sound_volume.ycp

all: $(ycp_files)
	@YAST2DIR@/bin/ycpdoc -d. $(ycp_files)

clean:
	rm -f *~ *.html