#
# Makefile.am for y2a_audio/doc/autodocs
#

docdir = @DOCDIR@
htmldir = $(docdir)/autodocs

html_DATA = index.html $(wildcard *.html)
MAINTAINERCLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.h
	cd $(srcdir)/../../src && @YAST2DIR@/bin/ydoc @RPMNAME@ *.h
	mv -f $(srcdir)/../../src/*.html .

clean-local:
	$(RM) $(html_DATA)
