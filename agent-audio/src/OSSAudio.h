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

//int blah(int X = 0, string Y);

/** 
 *  volume setting
 *  @param card card id
 *  @param channel name eg. "Master"
 *  @param value volume 0..100
 */
YCPValue ossSetVolume(const int value, const string channel = "", const string card = "");

/**
 * volume reading
 * @param card card id
 * @param channel channel name
 */
YCPValue ossGetVolume(const string channel = "", const string card = "");

#endif
