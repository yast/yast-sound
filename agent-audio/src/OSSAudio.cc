/* OSSAudio.cc
 *
 * Audio agent -- OSS functions.
 *
 * Authors: Michal Svec <msvec@suse.cz>
 *
 * $Id$
 */

#ifndef __OSSAudio_h
#define __OSSAudio_h

#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <linux/soundcard.h>

#include <Y2.h>
#include <scr/SCRAgent.h>
#include <scr/SCRInterpreter.h>

YCPValue ossSetVolume(const string card, const string& channel) {
}

/**
 * @builtin SCR (`Read (.volume)) -> integer
 * @builtin SCR (`Read (.volume.N)) -> integer
 *
 * Read a master volume. If called with just volume, /dev/mixer
 * is used, otherwise /dev/mixerN is used as a device.
 *
 * This call returns the volume on success and -1, if it fails.
 *
 * @example SCR (`Read (.volume)) -> 50
 * @example SCR (`Read (.volume.1)) -> -1
 *
 */

YCPValue ossGetVolume(const string card, const string channel, int value) {

    string mixerfile = "/dev/mixer";
    mixerfile += card;

    stereovolume volume;

    int mixer_fd = open(mixerfile.c_str(), O_RDWR, 0);
    if(mixer_fd < 0) {
	y2error("%s",string("cannot open mixer: '" + string(mixerfile) +
			    "' : " + string(strerror(errno))).c_str());
	/* FIXME y2error -> YCPError */
	return YCPInteger(-1);
    }

    if(ioctl(mixer_fd,MIXER_READ(SOUND_MIXER_VOLUME),&volume) == -1) {
	y2error(string("ioctl failed : " + string(strerror(errno))).c_str());
	return YCPInteger(-1);
    }

    if(volume.left != volume.right)
	y2warning("volume is not balanced (%d,%d)", volume.left, volume.right);

    int vol = volume.left;
    if(vol<0) {
	y2warning("read volume set to 0");
	vol=0;
    }
    if(vol>99) {
	y2warning("read volume set to 99");
	vol=99;
    }
}

#endif
