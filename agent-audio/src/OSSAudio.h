/* OSSAudio.h
 *
 * Audio agent -- OSS functions.
 *
 * Authors: Michal Svec <msvec@suse.cz>
 *
 * $Id$
 */

#ifndef __OSSAudio_h
#define __OSSAudio_h

#include <Y2.h>
#include <scr/SCRAgent.h>
#include <scr/SCRInterpreter.h>

/**
 * stereo volume structure for oss volume settings
 */
typedef struct {
    unsigned char left;
    unsigned char right;
} stereovolume;

/** 
 *  volume setting
 *  @param card card id
 *  @param channel name eg. "Master"
 *  @param value volume 0..100
 */
YCPValue ossSetVolume(const string card, const string channel, int value);

/**
 * volume reading
 * @param card card id
 * @param channel channel name
 */
YCPValue ossGetVolume(const string card, const string& channel);

#endif
