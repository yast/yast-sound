/* OSSAudio.h
 *
 * Audio agent -- OSS functions
 *
 * Authors: Michal Svec <msvec@suse.cz>
 */

#ifndef __OSSAudio_h
#define __OSSAudio_h

#include <YCP.h>

extern const char *ossChannels[];
extern int ossChannels_num;

using std::string;
using std::vector;
using std::map;

/**
 * Set a master volume. If called with just volume, /dev/mixer
 * is used, otherwise /dev/mixerN is used as a device.
 *
 * This call returns true on success and false, if it fails.
 *
 *  @param card card id (default if empty)
 *  @param channel name eg. "Master" ("Master" if empty)
 *  @param value volume 0..100
 *
 * @example
 *   SCR (`Write (.volume, 50)) -> true
 *   SCR (`Write (.volume.1, 50)) -> false
 */
YCPBoolean ossSetVolume(const string card, const string channel, const int value);

/**
 * Read a master volume. If called with just volume, /dev/mixer
 * is used, otherwise /dev/mixerN is used as a device.
 *
 * This call returns the volume on success and -1, if it fails.
 *
 * @param card card id (default if empty)
 * @param channel channel name (Master if empty)
 *
 * @example
 *   SCR (`Read (.volume)) -> 50
 *   SCR (`Read (.volume.1)) -> -1
 */
YCPValue ossGetVolume(const string card, const string channel);

#endif
