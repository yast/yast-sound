#
# Makefile.am for sound/agent-audio/doc/autodocs
#

htmldir = $(docdir)/autodocs

html_DATA = index.html $(wildcard *.html)
CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.h
	cd $(srcdir)/../../src && @ybindir@/ydoc agent-audio *.h
	mv -f $(srcdir)/../../src/*.html .
