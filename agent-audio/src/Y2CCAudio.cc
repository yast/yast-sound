#include "Y2CCAudio.h"
#include "Y2AudioComponent.h"


Y2CCAudio::Y2CCAudio()
    : Y2ComponentCreator(Y2ComponentBroker::BUILTIN)
{
}


bool
Y2CCAudio::isServerCreator() const
{
    return true;
}


Y2Component *
Y2CCAudio::create(const char *name) const {
    if (!strcmp(name, "ag_audio")) return new Y2AudioComponent();
    else return 0;
}

Y2CCAudio g_y2ccag_audio;
