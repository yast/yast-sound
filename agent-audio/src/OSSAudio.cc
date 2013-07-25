/* OSSAudio.cc
 *
 * Audio agent -- OSS functions
 *
 * Authors: Michal Svec <msvec@suse.cz>
 */

#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/soundcard.h>

#include <y2util/y2log.h>

#include "OSSAudio.h"

/**
 * stereo volume structure for oss volume settings
 */
typedef struct {
    unsigned char left;
    unsigned char right;
} stereovolume;

/* channels' names, to be used for channel to nubmer mapping sometime */
const char *ossChannels[] = SOUND_DEVICE_LABELS;
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
	return -1;
    }
}

YCPBoolean ossSetVolume(const string card, const string channel, const int value) {

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
	{
	    y2error("bad channel specification: %s", channel.c_str());
	    return YCPBoolean(false);
	}
    }

    stereovolume volume;
    volume.left = vol;
    volume.right = vol;

    int mixer_fd = open(mixerfile.c_str(), O_RDWR, 0);
    if(mixer_fd < 0) {
	string error = string("cannot open mixer: '" 
			+ string(mixerfile) 
			+ "' : " 
			+ string(strerror(errno))).c_str();
	y2error("Error: %s", error.c_str());
	return YCPBoolean(false);
    }

    if(ioctl(mixer_fd,MIXER_WRITE(device),&volume) == -1) {
	string error = string("ioctl failed : ")
			+ strerror(errno);
	close(mixer_fd);
	y2error("Error: %s", error.c_str());
	return YCPBoolean(false);
    }

    close(mixer_fd);
    return YCPBoolean (true);
}

YCPValue ossGetVolume(const string card, const string channel) {

    string mixerfile = "/dev/mixer";
    mixerfile += card;
    y2debug("mixerfile=%s",mixerfile.c_str());

    stereovolume volume;

    int device = SOUND_MIXER_VOLUME;
    if(channel!="") {
	device = ossDevice(channel);
	if(device == -1)
	{
	    string error = string("bad channel specification: ") + channel.c_str();
            return YCPError(error);	    
	}
    }
    y2debug("device=%d",device);

    int mixer_fd = open(mixerfile.c_str(), O_RDWR, 0);
    if(mixer_fd < 0) {
	string error = string("cannot open mixer: '")
			+ mixerfile 
			+ "' : " 
			+ strerror(errno);
	return YCPError(error, YCPInteger(-1));
    }

    if(ioctl(mixer_fd,MIXER_READ(device),&volume) == -1) {
	string error = string("ioctl failed : ") + strerror(errno);
	close(mixer_fd);
	return YCPError(error, YCPInteger(-1));
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

