#
# Makefile.am for y2a_audio/doc/autodocs
#
# $Id$
#

docdir = @DOCDIR@
htmldir = $(docdir)/autodocs

html_DATA = index.html $(wildcard *.html)
CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.h
	cd $(srcdir)/../../src && @YAST2DIR@/bin/ydoc @RPMNAME@ *.h
	mv -f $(srcdir)/../../src/*.html .
