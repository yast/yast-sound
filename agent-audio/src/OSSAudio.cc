/* OSSAudio.cc
 *
 * Audio agent -- OSS functions
 *
 * Authors: Michal Svec <msvec@suse.cz>
 *
 * $Id$
 */

#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <linux/soundcard.h>

#define y2log_component "ag_audio"

#include <Y2.h>
#include <scr/SCRAgent.h>
#include <scr/SCRInterpreter.h>

#include "OSSAudio.h"

/**
 * stereo volume structure for oss volume settings
 */
typedef struct {
    unsigned char left;
    unsigned char right;
} stereovolume;

/* channels' names, to be used for channel to nubmer mapping sometime */
char *ossChannels[] = SOUND_DEVICE_LABELS;
int ossChannels_num = SOUND_MIXER_NRDEVICES;

/**
 * convert channel string to oss device number
 * FIXME: use ossChannels for convertion [make a map in constructor -> search]
 */
int ossDevice(const string channel) {
    if(channel=="" || channel=="Master") return SOUND_MIXER_VOLUME;
    else if(channel=="BASS") return SOUND_MIXER_BASS;
    else if(channel=="TREBLE") return SOUND_MIXER_TREBLE;
    else if(channel=="SYNTH") return SOUND_MIXER_SYNTH;
    else if(channel=="PCM") return SOUND_MIXER_PCM;
    else if(channel=="SPEAKER") return SOUND_MIXER_SPEAKER;
    else if(channel=="LINE") return SOUND_MIXER_LINE;
    else if(channel=="MIC") return SOUND_MIXER_MIC;
    else if(channel=="CD") return SOUND_MIXER_CD;
    else if(channel=="IMIX") return SOUND_MIXER_IMIX;
    else if(channel=="ALTPCM") return SOUND_MIXER_ALTPCM;
    else if(channel=="RECLEV") return SOUND_MIXER_RECLEV;
    else if(channel=="IGAIN") return SOUND_MIXER_IGAIN;
    else if(channel=="OGAIN") return SOUND_MIXER_OGAIN;
    else if(channel=="LINE1") return SOUND_MIXER_LINE1;
    else if(channel=="LINE2") return SOUND_MIXER_LINE2;
    else if(channel=="LINE3") return SOUND_MIXER_LINE3;
    else if(channel=="DIGITAL1") return SOUND_MIXER_DIGITAL1;
    else if(channel=="DIGITAL2") return SOUND_MIXER_DIGITAL2;
    else if(channel=="DIGITAL3") return SOUND_MIXER_DIGITAL3;
    else if(channel=="PHONEIN") return SOUND_MIXER_PHONEIN;
    else if(channel=="PHONEOUT") return SOUND_MIXER_PHONEOUT;
    else if(channel=="VIDEO") return SOUND_MIXER_VIDEO;
    else if(channel=="RADIO") return SOUND_MIXER_RADIO;
    else if(channel=="MONITOR") return SOUND_MIXER_MONITOR;
    // else if(channel=="") return SOUND_MIXER_;
    else {
	y2error("bad channel specification: %s", channel.c_str());
	return -1;
    }
}

/**
 * @builtin SCR (`Write (.volume, integer volume)) -> bool
 * @builtin SCR (`Write (.volume.N, integer volume)) -> bool
 *
 * Set a master volume. If called with just volume, /dev/mixer
 * is used, otherwise /dev/mixerN is used as a device.
 *
 * This call returns true on success and false, if it fails.
 *
 * @example SCR (`Write (.volume, 50)) -> true
 * @example SCR (`Write (.volume.1, 50)) -> false
 */
YCPValue ossSetVolume(const string card, const string channel, const int value) {

    string mixerfile = "/dev/mixer";
    mixerfile += card;

    int vol = value;
    if(vol<0) {
	y2warning("volume set to 0");
	vol=0;
    }
    if(vol>99) {
	y2warning("volume set to 99");
	vol=99;
    }

    int device = SOUND_MIXER_VOLUME;
    if(channel!="") {
	device = ossDevice(channel);
	if(device == -1)
	    return YCPBoolean(false);
    }

    stereovolume volume;
    volume.left = vol;
    volume.right = vol;

    int mixer_fd = open(mixerfile.c_str(), O_RDWR, 0);
    if(mixer_fd < 0) {
	y2error("%s",string("cannot open mixer: '" + string(mixerfile) +
			    "' : " + string(strerror(errno))).c_str());
	/* FIXME y2error -> YCPError */
	return YCPBoolean(false);
    }

    if(ioctl(mixer_fd,MIXER_WRITE(device),&volume) == -1) {
	y2error(string("ioctl failed : " + string(strerror(errno))).c_str());
	close(mixer_fd);
	return YCPBoolean(false);
    }

    close(mixer_fd);
    return YCPBoolean (true);
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
 */
YCPValue ossGetVolume(const string card, const string channel) {

    string mixerfile = "/dev/mixer";
    mixerfile += card;
    y2debug("mixerfile=%s",mixerfile.c_str());

    stereovolume volume;

    int device = SOUND_MIXER_VOLUME;
    if(channel!="") {
	device = ossDevice(channel);
	if(device == -1)
	    return YCPBoolean(false);
    }
    y2debug("device=%d",device);

    int mixer_fd = open(mixerfile.c_str(), O_RDWR, 0);
    if(mixer_fd < 0) {
	y2error("%s",string("cannot open mixer: '" + string(mixerfile) +
			    "' : " + string(strerror(errno))).c_str());
	/* FIXME y2error -> YCPError */
	return YCPInteger(-1);
    }

    if(ioctl(mixer_fd,MIXER_READ(device),&volume) == -1) {
	y2error(string("ioctl failed : " + string(strerror(errno))).c_str());
	close(mixer_fd);
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

    close(mixer_fd);
    return YCPInteger(vol);
}

