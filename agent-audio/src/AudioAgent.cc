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
YCPValue AudioAgent::Read ( const YCPPath &path, const YCPValue& arg,
			    const YCPValue& opt) {

    // Same as Dir()
    if(path->length()==0) {
	return Dir(path);
    }

    // Fetch parameters
    svect args;
    for(int i=0; i<path->length(); i++)
	args.push_back(path->component_str(i));

    // OSS Read handling
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

    // Alsa Read handling
    else if(args[0]=="alsa") {
	switch(path->length()) {
	    // snd cards name
	    case 4:
		if(args[1]=="cards" && args[3]=="name")
		    return alsaGetCardName(atoi(args[2].c_str()));
		break;
	    // volume reading
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

    string error = string("Wrong path in Read(): .audio") +  path->toString().c_str();
    return YCPError(error);
}

/**
 * Write
 */
YCPBoolean AudioAgent::Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg)
{
    // Do nothing
    if(path->length()==0) {
	return YCPBoolean(false);
    }

    // Fetch parameters
    svect args;
    for(int i=0; i<path->length(); i++)
        args.push_back(path->component_str(i));

    if(!value->isInteger() && !value->isBoolean()) {
	string error = string("Wrong argument (")
			+ value->toString().c_str()
			+ ") passed to Write(): .audio"
			+ path->toString().c_str();
	y2error("Error: %s", error.c_str());
	return YCPBoolean(false);
    }


    // OSS Write handling
    if(args[0]=="oss") {
	int volume = value->asInteger()->value();
	y2debug("oss: (%ld) %s", path->length(), path->toString().c_str());
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

    // Alsa Write handling
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

    y2error("Wrong path in Write(): .audio%s", path->toString().c_str());
    return YCPBoolean(false);
}

/**
 * Dir
 */
YCPList AudioAgent::Dir(const YCPPath& path) {

    YCPList list;

    svect args;
    for(int i=0; i<path->length(); i++)
        args.push_back(path->component_str(i));

    switch(path->length()) {
	case 0:
	    list->add(YCPString("alsa"));
	    list->add(YCPString("oss"));
	    list->add(YCPString("common"));
	    return list;
	case 1:
	    list->add(YCPString("cards"));
	    if(args[0]=="alsa") {
		list->add(YCPString("store"));
		list->add(YCPString("restore"));
	    }
	    return list;
	case 2:
	    if(args[0]=="alsa" && args[1]=="cards")
		return alsaGetCards();
	    break;
	case 3:
	    if(args[1]=="cards") {
		if(args[0]=="alsa") {
		    list->add(YCPString("name"));
		    list->add(YCPString("store"));
		    list->add(YCPString("restore"));
		}
		list->add(YCPString("channels"));
		return list;
	    }
	    break;
	case 4:
	    if(args[0]=="alsa") {
		if(args[1]=="cards" && args[3]=="channels")
		{
		    return alsaGetChannels(atoi(args[2].c_str()));
		}
	    }
	    else if(args[0]=="oss") {
		if(args[1]=="cards" && args[3]=="channels") {
		    y2debug("sc=%d",ossChannels_num);
		    for(int cur = 0; cur < ossChannels_num; cur++)
			list->add(YCPString(ossChannels[cur]));
		    return list;
		}
	    }
	    break;
	case 5:
	    if(args[0]=="alsa") {
		if(args[1]=="cards" && args[3]=="channels") {
		    list->add(YCPString("mute"));
		    return list;
                }
	    }
	    break;
    }

    y2error("Wrong path in Dir(): .audio%s", path->toString().c_str());
    return YCPList();
}

YCPValue AudioAgent::Execute(const YCPPath& path, const YCPValue& value,
			     const YCPValue& arg)
{
    svect args;
    for(int i=0; i<path->length(); i++)
        args.push_back(path->component_str(i));

    if(args[0]=="alsa")
    {
	int card_id=-1;
	// alsa part
	if(path->length()==4 && args[1]=="cards")
	{
	    card_id=atoi(args[2].c_str());
	}

	if(args[path->length()-1]=="store")
	{
	    return alsaStore(card_id);
        }
        else if(args[path->length()-1]=="restore")
        {
	    return alsaRestore(card_id);
	}
    }
    else if(args[0]=="oss" || args[0]=="common")
    {
	// oss part
    }

    string error = string("Wrong path in Execute(): .audio") + path->toString().c_str();
    return YCPVoid();
}

/**
 * otherCommand
 */
YCPValue AudioAgent::otherCommand(const YCPTerm& term) {

    string sym = term->name();
    if (sym == "AudioAgent") {

	return YCPVoid();
    }

    return YCPNull();
}

