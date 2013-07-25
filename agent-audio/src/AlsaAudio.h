// -*- c++ -*-

/**
 * File:
 *   AlsaAudio.h
 *
 * Module:
 *   audio agent
 *
 * Summary:
 *   agent/ycp interface. alsa functions
 *
 * Authors:
 *   dan.meszaros <dmeszar@suse.cz>
 *
 * interface for acces to alsa/oss sound system from ycp script
 */


#ifndef __ALSAAUDIO
#define __ALSAAUDIO

#include <YCP.h>

using std::string;
using std::vector;
using std::map;

/** 
 *  volume setting
 *  @param card card id
 *  @param channel_name name eg. "Master"
 *  @param value volume 0..100
 */

YCPBoolean alsaSetVolume(int card, const string& channel_name, int value);

/**
 * volume reading
 * @param card card id
 * @param channel_name channel name
 */

YCPValue alsaGetVolume(int card, const string& channel_name);

/**
 * setMute
 * @param card card id
 * @param channel_name channel name
 * @param value boolean mute/unmute
 */

YCPBoolean alsaSetMute(int card, const string& channel_name, bool value);
YCPValue alsaGetMute(int card, const string& channel_name);

/**
 * getChannels- list of available channels for card #id
 * @param card card id
 *
 */

YCPList alsaGetChannels(int card);

/** getCards
 *  returns list of running cards- list of strings
 */

YCPList alsaGetCards();

/** alsaGetCardName
 * returns (long) name of card
 */

YCPValue alsaGetCardName(int card_id);

/**
 * stores setting for given card. if card==-1 store all.
 * param card card id
 */

YCPValue alsaStore(int card=-1);

/**
 * restores settings for given card. if card==-1 restore all.
 *
 */
 
YCPValue alsaRestore(int card=-1);

#endif
