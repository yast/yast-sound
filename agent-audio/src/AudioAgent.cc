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
 *   Michal Svec <msvec@suse.cz>
 *
 * $Id$
 *
 * interface for acces to alsa/oss sound system from ycp script
 *
 */

#include "AudioAgent.h"
#include "AlsaAudio.h"
#include "OSSAudio.h"

typedef vector<string> svect;

/**
 * AudioAgent
 */
AudioAgent::AudioAgent() : SCRAgent() {
}

/**
 * ~AudioAgent
 */
AudioAgent::~AudioAgent() {
}

/**
 * Read
 */
YCPValue AudioAgent::Read(const YCPPath &path, const YCPValue& arg) {

    /* Same as Dir() */
    if(path->length()==0) {
	return Dir(path);
    }

    /* Fetch parameters */
    svect args;
    for(int i=0; i<path->length(); i++)
	args.push_back(path->component_str(i));

    /* OSS Read handling */
    if(args[0]=="oss") {
	y2debug("oss: (%ld) %s", path->length(), path->toString().c_str());
	switch(path->length()) {
	    case 1:
		return ossGetVolume("", "");
	    case 2:
		if(args[1]=="cards")
		    return ossGetVolume("", "");
		break;
	    case 3:
		if(args[1]=="cards")
		    return ossGetVolume(args[2], "");
		break;
	    case 5:
		if(args[1]=="cards" && args[3]=="channels")
		    return ossGetVolume(args[2], args[4]);
	}
    }

    /* Alsa Read handling */
    else if(args[0]=="alsa") {
	switch(path->length()) {
	    /* snd cards name */
	    case 4:
		if(args[1]=="cards" && args[3]=="name")
		    return YCPString("cardname"); // alsaCardName(atoi(args[2].c_str())))
		break;
	    /* volume reading */
	    case 6:
		if(args[1]=="cards" && args[3]=="channels") {
		    if(args[5]=="volume")
			return alsaGetVolume(atoi(args[2].c_str()), args[4].c_str());
		    else if(args[5]=="mute")
			return alsaGetMute(atoi(args[2].c_str()), args[4].c_str());
		    break;
		}
	} 
    }
    
    y2error("Wrong path '%s' in Read().", path->toString().c_str());
    return YCPVoid();
}

/**
 * Write
 */
YCPValue AudioAgent::Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg) 
{
    /* Do nothing */
    if(path->length()==0) {
	return YCPBoolean(false);
    }
    
    /* Fetch parameters */
    svect args;
    for(int i=0; i<path->length(); i++)
        args.push_back(path->component_str(i));

    if(!value->isInteger()) {
	y2error("bad argument to Write: %s", value->toString().c_str());
	return YCPBoolean(false);
    }

    int volume = value->asInteger()->value();

    /* OSS Write handling */
    if(args[0]=="oss") {
	switch(path->length()) {
	    case 1:
		return ossSetVolume("", "", volume);
	    case 2:
		if(args[1]=="cards")
		    return ossSetVolume("", "", volume);
		break;
	    case 3:
		if(args[1]=="cards")
		    return ossSetVolume(args[2], "", volume);
		break;
	    case 5:
		if(args[1]=="cards" && args[3]=="channels")
		    return ossSetVolume(args[2], args[4], volume);
	}
    }

    /* Alsa Write handling */
    else if(args[0]=="alsa") {
        switch(path->length()) {
	    case 6:
		if(args[1]=="cards" && args[3]=="channels") {
		    if(args[5]=="volume")
			return alsaSetVolume(atoi(args[2].c_str()), args[4].c_str(), value->asInteger()->value());
		    else if(args[5]=="mute")
			return alsaSetMute(atoi(args[2].c_str()), args[4].c_str(), value->asBoolean()->value());
		}
		break;
        }
    }

    y2error("Wrong path '%s' in Write().", path->toString().c_str());
    return YCPVoid();
}

/** 
 * Dir
 */
YCPValue AudioAgent::Dir(const YCPPath& path) {
    YCPList list;

    svect args;
    for(int i=0; i<path->length(); i++)
        args.push_back(path->component_str(i));

    switch(path->length())
    {
	case 0:
	    list->add(YCPString("alsa"));
	    list->add(YCPString("oss"));
	    list->add(YCPString("common"));
	    return list;
	case 1:
	    list->add(YCPString("cards"));
	    list->add(YCPString("restore"));
	    list->add(YCPString("store"));
	    return list;
	case 2:
	    if(args[0]=="alsa" && args[1]=="cards")
	    {
		return alsaGetCards();
	    }
	    else if(args[0]=="oss" || args[0]=="common")
	    {
		
		// TODO
		return list;
	    }
	    break;
	case 3:
	    if(args[1]=="cards")
	    {
		list->add(YCPString("channels"));
		list->add(YCPString("name"));
		list->add(YCPString("store"));
		list->add(YCPString("restore"));
		return list;
	    }
	    break;

	case 4:
	    if(args[0]=="alsa")
	    {
		if(args[1]=="cards" && args[3]=="channels")
		{
		    return alsaGetChannels(atoi(args[2].c_str()));  
		}
	    }
	    break;
	case 5:
	    if(args[0]=="alsa")
	    {
		if(args[1]=="cards" && args[3]=="channels")
                {   
		    list->add(YCPString("volume"));
		    list->add(YCPString("mute"));
		    return list;
                }
	    }
	    /*
	    else if(s_system=="oss" || s_system=="common")
	    {
		// TODO
	    }
	    */
	    /*
	    else if(s_system=="oss" || s_system=="common")
	    {
		list->add(YCPString("volume"));
		return list;
	    }
	    */
	    
    }

    y2error("Wrong path '%s' in Dir().", path->toString().c_str());
    return YCPVoid();
}

/**
 * otherCommand
 */
YCPValue AudioAgent::otherCommand(const YCPTerm& term) {
    return YCPVoid();
}

