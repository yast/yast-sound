

#include "Y2AudioComponent.h"
#include <scr/SCRInterpreter.h>
#include "AudioAgent.h"


Y2AudioComponent::Y2AudioComponent()
    : interpreter(0),
      agent(0)
{
}


Y2AudioComponent::~Y2AudioComponent()
{
    if (interpreter) {
        delete interpreter;
    }
    if(agent) {
        delete agent;
    }
}


bool
Y2AudioComponent::isServer() const
{
    return true;
}


string
Y2AudioComponent::name() const
{
    return "ag_audio";
}


YCPValue
Y2AudioComponent::evaluate(const YCPValue& value)
{
    if (!interpreter) {
	agent = new AudioAgent();
	interpreter = new SCRInterpreter(agent);
    }
    
    return interpreter->evaluate(value);
}
