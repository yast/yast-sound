// -*- c++ -*-

/**
 * File:
 *   AudioAgent.h
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
 */


#ifndef __AUDIOAGENT
#define __AUDIOAGENT

#define y2log_component "ag_audio"

#include <Y2.h>
#include <scr/SCRAgent.h>
#include <scr/SCRInterpreter.h>

class AudioAgent;

/* An interface class between YaST2 and RcFile */
class AudioAgent : public SCRAgent {
public:
    AudioAgent();
    virtual ~AudioAgent();
    
    virtual YCPValue Read(const YCPPath &path, const YCPValue& arg = YCPNull());
    virtual YCPValue Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg = YCPNull());
    virtual YCPValue Dir(const YCPPath& path);
    
    virtual YCPValue otherCommand(const YCPTerm& term);
};

#endif /* _AudioAgent_h */
