// -*- c++ -*-

#ifndef __Y2CCAUDIOCOMPONENT
#define __Y2CCAUDIOCOMPONENT

#include "Y2.h"

class SCRInterpreter;
class AudioAgent;

class Y2AudioComponent : public Y2Component
{
    SCRInterpreter *interpreter;
    AudioAgent *agent;
    
public:
    /**
     * Create a new Y2RcConfigComponent
     */
    Y2AudioComponent();
    
    /**
     * Cleans up
     */
    ~Y2AudioComponent();
    
    /**
     * Returns true: The scr is a server component
     */
    bool isServer() const;
    
    /**
     * Returns true: The scr is a server component
     */
    virtual string name() const;
    
    /**
     * Evalutas a command to the scr
     */
    virtual YCPValue evaluate(const YCPValue& command);
};

#endif
