/* OSSAudio.h
 *
 * Audio agent -- OSS functions
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

extern char *ossChannels[];
extern int ossChannels_num;

/** 
 *  volume setting
 *  @param card card id (default if empty)
 *  @param channel name eg. "Master" ("Master" if empty)
 *  @param value volume 0..100
 */
YCPValue ossSetVolume(const string card, const string channel, const int value);

/**
 * volume reading
 * @param card card id (default if empty)
 * @param channel channel name (Master if empty)
 */
YCPValue ossGetVolume(const string card, const string channel);

#endif
