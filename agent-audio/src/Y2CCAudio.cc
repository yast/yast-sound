#include <scr/Y2AgentComponent.h>
#include <scr/Y2CCAgentComponent.h>

#include "AudioAgent.h"

typedef Y2AgentComp <AudioAgent> Y2AudioAgentComp;

Y2CCAgentComp <Y2AudioAgentComp> g_y2ccag_audio ("ag_audio");
