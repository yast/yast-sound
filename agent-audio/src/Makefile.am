#
# Makefile.am for y2a_audio/src
#

CXXFLAGS += -Wall

plugindir = $(YAST2DIR)/plugin

plugin_LTLIBRARIES = libpy2ag_audio.la
noinst_LTLIBRARIES = liby2ag_audio.la

liby2ag_audio_la_SOURCES =		\
	OSSAudio.cc	OSSAudio.h	\
	AudioAgent.cc	AudioAgent.h	\
	AlsaAudio.cc	AlsaAudio.h
liby2ag_audio_la_LDFLAGS = $(LDFLAGS) -version-info 2:0 `test -e /usr/lib/libasound.so && echo -lasound`

libpy2ag_audio_la_SOURCES =				\
	$(liby2ag_audio_la_SOURCES)			\
	Y2CCAudio.cc         Y2CCAudio.h		\
	Y2AudioComponent.cc  Y2AudioComponent.h
libpy2ag_audio_la_LDFLAGS = $(LDFLAGS) -version-info 2:0 `test -e /usr/lib/libasound.so && echo -lasound`

INCLUDES = -I$(includedir)

