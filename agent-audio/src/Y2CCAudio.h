// -*- c++ -*-

#ifndef __Y2CCAUDIO
#define __Y2CCAUDIO

#include "Y2.h"

class Y2CCAudio : public Y2ComponentCreator
{
public:
    /**
     * Creates a new Y2CCRcConfig object.
     */
    Y2CCAudio();
    
    /**
     * Returns true: The RcConfig agent is a server component.
     */
    bool isServerCreator() const;
    
    /**
     * Creates a new @ref Y2SCRComponent, if name is "ag_rcconfig".
     */
    virtual Y2Component *create(const char *name) const;
};

#endif
