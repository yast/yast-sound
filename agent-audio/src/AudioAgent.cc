/**
 * File:
 *   AudioAgent.cc
 *
 * Module:
 *   audio agent
 *
 * Summary:
 *   agent/ycp interface
 *
 * Authors:
 *   dan.meszaros <dmeszar@suse.cz>
 *
 * $Id$
 *
 * interface for acces to alsa/oss sound system from ycp script
 *
 */

#include "AudioAgent.h"
#include "AlsaAudio.h"
#include <sys/asoundlib.h>
#include <math.h>

/* AudioAgent */
AudioAgent::AudioAgent() : SCRAgent() {
}

AudioAgent::~AudioAgent() {
}

/**
 */

YCPValue AudioAgent::Read(const YCPPath &path, const YCPValue& arg) {
    if(path->length()==0)
    {
	// do nothing
	return YCPVoid();
    }

    int card_id=-1;
    string s_system="";
    string channel="";
    string action=""; // "volume"/"mute"

    // fetch parameters
    switch(path->length())
    {
	case 4:
	    action=path->component_str(3).c_str();
	case 3:
	    channel=path->component_str(2).c_str();
	case 2:
	    card_id=atoi(path->component_str(1).c_str());
	case 1:
	    s_system=path->component_str(0).c_str();
    }
    
    if(s_system=="alsa")
    {
	switch(path->length())
	{
	    case 1:
		return alsaRestore(-1);
	    case 2:
		return alsaRestore(card_id);
	    case 3:
		// undefined
		y2error("attempt to read '.audio.alsa.#chan', whose value is undefined");
		return YCPVoid();
	    case 4:
		if(action=="mute")
		{
		    return alsaGetMute(card_id, channel.c_str());
		}
		else if(action=="volume")
		{
		    return alsaGetVolume(card_id, channel.c_str());
		}
		return YCPVoid();
	}
	return YCPVoid();

    }
    /*
    else if(s_system=="oss" || s_system=="common")
    {
    }
    */
    
    y2error("Wrong path '%s' in Read().", path->toString().c_str());
    return YCPVoid();
}

/**
 */

YCPValue AudioAgent::Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg) 
{
    if(path->length()==0)
    {
        // do nothing
        return YCPBoolean(false);
    }

    int card_id=-1;
    string s_system="";
    string channel="";
    string action=""; // "volume"/"mute"

    // fetch parameters
    switch(path->length())
    {
        case 4:
            action=path->component_str(3).c_str();
        case 3:
            channel=path->component_str(2).c_str();
        case 2:
            card_id=atoi(path->component_str(1).c_str());
        case 1:
            s_system=path->component_str(0).c_str();
    }

    if(s_system=="alsa")
    {
        switch(path->length())
        {
            case 1:
                return alsaStore(-1);
            case 2:
                return alsaStore(card_id);
            case 3:
                // undefined
                y2error("attempt to write to '.audio.alsa.#card.channel', whose value is undefined");
                return YCPVoid();
            case 4:
                if(action=="mute")
                {
		    return alsaSetMute(card_id, channel.c_str(), value->asBoolean()->value());
                }
                else if(action=="volume")
                {
                    return alsaSetVolume(card_id, channel.c_str(), value->asInteger()->value());
                }
                return YCPVoid();
        }
        return YCPVoid();

    }
    else if(s_system=="oss" || s_system=="common")
    {

    }

    y2error("Wrong path '%s' in Write().", path->toString().c_str());
    return YCPVoid();
}

/** 
 */

YCPValue AudioAgent::Dir(const YCPPath& path) {
    YCPList list;

    string channel;
    int card_id=-1;
    string s_system;    

    switch(path->length())
    {
	case 3:
	    channel=path->component_str(2).c_str();
	case 2:
	    card_id=atoi(path->component_str(1).c_str());
	case 1:
	    s_system=path->component_str(0);
    }

    switch(path->length())
    {
	case 0:
	    list->add(YCPString("alsa"));
	    list->add(YCPString("oss"));
	    list->add(YCPString("common"));
	    return list;
	case 1:
	    if(s_system=="alsa")
	    {
		return alsaGetCards();
	    }
	    else if(s_system=="oss" || s_system=="common")
	    {
		return list;
	    }
	case 2:
	    if(s_system=="alsa")
	    {
		return alsaGetChannels(card_id);
	    }
	    /*
	    else if(s_system=="oss" || s_system=="common")
	    {
		return list;
	    }
	    */
	case 3:
	    if(s_system=="alsa")
	    {
		list->add(YCPString("mute"));
		list->add(YCPString("volume"));
		return list;
	    }
	    /*
	    else if(s_system=="oss" || s_system=="common")
	    {
		return list;
	    }
	    */
	    
    }

    y2error("Wrong path '%s' in Dir().", path->toString().c_str());
    return YCPVoid();
}

/**
 */

YCPValue AudioAgent::otherCommand(const YCPTerm& term) {
    return YCPVoid();
}

