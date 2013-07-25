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
 * interface for acces to alsa/oss sound system from ycp script
 */


#ifndef __AUDIOAGENT
#define __AUDIOAGENT

#include <scr/SCRAgent.h>

using std::string;
using std::vector;
using std::map;

#include "AlsaAudio.h"
#include "OSSAudio.h"

/* An interface class between YaST2 and RcFile */
class AudioAgent : public SCRAgent {
public:
    AudioAgent();
    virtual ~AudioAgent();
    
    virtual YCPValue Read (	const YCPPath &path,
				const YCPValue& arg = YCPNull(),
				const YCPValue& opt = YCPNull());

    virtual YCPBoolean Write (	const YCPPath &path,
				const YCPValue& value,
				const YCPValue& arg = YCPNull());
    
    virtual YCPList Dir (	const YCPPath& path);
    
    virtual YCPValue Execute (	const YCPPath& path,
				const YCPValue& value = YCPNull(),
				const YCPValue& arg = YCPNull());
    
    virtual YCPValue otherCommand(const YCPTerm& term);
};

#endif /* _AudioAgent_h */
