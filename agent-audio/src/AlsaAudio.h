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
 * $Id$
 *
 * interface for acces to alsa/oss sound system from ycp script
 */


#ifndef __ALSAAUDIO
#define __ALSAAUDIO

#include <Y2.h>
#include <scr/SCRAgent.h>

using std::string;
using std::vector;
using std::map;

/** 
 *  volume setting
 *  @param card card id
 *  @param channel name eg. "Master"
 *  @param value volume 0..100
 */

YCPValue alsaSetVolume(int card, const string& channel, int value);

/**
 * volume reading
 * @param card card id
 * @param channel channel name
 */

YCPValue alsaGetVolume(int card, const string& channel);

/**
 * setMute
 * @param card card id
 * @param channel channel name
 * @param value boolean mute/unmute
 */

YCPValue alsaSetMute(int card, const string& channel, bool value);
YCPValue alsaGetMute(int card, const string& channel);

/**
 * getChannels- list of available channels for card #id
 * @param card card id
 *
 */

YCPValue alsaGetChannels(int card);

/** getCards
 *  returns list of running cards- list of strings
 */

YCPValue alsaGetCards();

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
