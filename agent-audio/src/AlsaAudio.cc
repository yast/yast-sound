#include <math.h>
#include <sys/asoundlib.h>

#define y2log_component "ag_audio"

#include <Y2.h>
#include <scr/SCRAgent.h>
#include <scr/SCRInterpreter.h>

#include "AlsaAudio.h"

YCPValue alsaGetVolume(int card, const string& channel)
{
    snd_mixer_t* handle;
    int err=snd_mixer_open(&handle, card, 0);
    if(err<0)
    {
        return YCPVoid();
    }
    snd_mixer_gid_t gid;
    snd_mixer_group_t group;

    memset(&gid, 0, sizeof(gid));
    memset(&group, 0, sizeof(group));

    strcpy((char*)gid.name, channel.c_str());
    group.gid=gid;

    if(snd_mixer_group_read(handle, &group)<0)
    {
        y2error("invalid group (channel) '%s'", channel.c_str());
        snd_mixer_close(handle);
        return YCPVoid();
    }
    snd_mixer_close(handle);

    int val=group.volume.values[0];

    int range = group.max - group.min;
    int tmp;

    if (range == 0)
    {
	return YCPInteger((long long int)0);
    }

    tmp = rint((double)(val - group.min)/(double)(range)*100.0);
    return YCPInteger((long long int)tmp);
}

YCPValue alsaGetMute(int card, const string& channel)
{
    snd_mixer_t* handle;
    int err=snd_mixer_open(&handle, card, 0);
    if(err<0)
    {
        return YCPVoid();
    }
    snd_mixer_gid_t gid;
    snd_mixer_group_t group;

    memset(&gid, 0, sizeof(gid));
    memset(&group, 0, sizeof(group));

    strcpy((char*)gid.name, channel.c_str());
    group.gid=gid;

    if(snd_mixer_group_read(handle, &group)<0)
    {
        y2error("invalid group (channel) '%s'", channel.c_str());
        snd_mixer_close(handle);
        return YCPVoid();
    }
    snd_mixer_close(handle);

    return group.mute?YCPBoolean(true):YCPBoolean(false);
}

YCPValue alsaSetVolume(int card, const string& channel, int value) 
{
    snd_mixer_t* handle;

    int err=snd_mixer_open(&handle, card, 0);
    if(err<0)
    {
        return YCPBoolean(false);
    }

    snd_mixer_gid_t gid;
    snd_mixer_group_t group;

    memset(&gid, 0, sizeof(gid));
    memset(&group, 0, sizeof(group));

    strcpy((char*)gid.name, channel.c_str());
    group.gid=gid;

    if(snd_mixer_group_read(handle, &group)<0)
    {
        y2error("invalid group '%s'", channel.c_str());
        snd_mixer_close(handle);
        return YCPBoolean(false);
    }

    int range = group.max - group.min;
    int tmp;

    if (range == 0)
    {
	tmp=0;
    }
    else
    {
	tmp = rint((double)(value)*(double)(range)*0.01);
    }

    for(uint pos=0; pos<group.channels; pos++)
    {
	group.volume.values[pos]=tmp;
    }

    snd_mixer_group_write(handle, &group);
    snd_mixer_close(handle);

    return YCPBoolean(true);
}

YCPValue alsaSetMute(int card, const string& channel, bool value)
{
    snd_mixer_t* handle;

    int err=snd_mixer_open(&handle, card, 0);
    if(err<0)
    {
        return YCPBoolean(false);
    }
    
    snd_mixer_gid_t gid;
    snd_mixer_group_t group;

    memset(&gid, 0, sizeof(gid));
    memset(&group, 0, sizeof(group));

    strcpy((char*)gid.name, channel.c_str());
    group.gid=gid;

    if(snd_mixer_group_read(handle, &group)<0)
    {
        y2error("invalid group '%s'", channel.c_str());
        snd_mixer_close(handle);
        return YCPBoolean(false);
    }

    group.mute=value;

    snd_mixer_group_write(handle, &group);
    snd_mixer_close(handle);

    return YCPBoolean(true);
}

YCPValue alsaGetChannels(int card)
{
    snd_mixer_t *handle;
    snd_mixer_groups_t groups;
    snd_mixer_gid_t *group;

    if(snd_mixer_open(&handle, card, 0)<0)
    {
        return YCPVoid();
    }

    memset(&groups, 0, sizeof(groups));

    YCPList list;
    snd_mixer_groups(handle, &groups);
    groups.pgroups = (snd_mixer_gid_t *)malloc(groups.groups_over * sizeof(snd_mixer_eid_t));
    groups.groups_size = groups.groups_over;
    groups.groups_over = groups.groups = 0;
    snd_mixer_groups(handle, &groups);

    for (int idx = 0; idx < groups.groups; idx++) {
            group = &groups.pgroups[idx];
            list->add(YCPString((char*)group->name));
    }
    free(groups.pgroups);
    snd_mixer_close(handle);
    return list;
}

YCPValue alsaGetCards()
{
    YCPList list;
    int cnt=snd_cards();
    char str[4];
    for(int i=0; i<cnt; i++)
    {
        sprintf(str, "%d", i);
        list->add(YCPString(str));
    }
    return list;
}

YCPValue alsaStore(int card=-1)
{
    string cmd="/usr/sbin/alsactl store";
    if(card>=0)
    {
	// add card id
	cmd+=" ";
	char tmp[32];
	sprintf(tmp, "%d", card);
	cmd+=tmp;
    }
    cmd+=" > /dev/null";
    if(system(cmd.c_str())!=-1)
    {
	return YCPBoolean(true);
    }
    return YCPBoolean(false);
}

YCPValue alsaRestore(int card=-1)
{
    string cmd="/usr/sbin/alsactl restore";
    if(card>=0)
    {
        // add card id
        cmd+=" ";
	char tmp[32];
	sprintf(tmp, "%d", card);
	cmd+=tmp;
    }
    cmd+=" > /dev/null";
    y2error("executing '%s'", cmd.c_str());
    if(system(cmd.c_str()))
    {
        return YCPBoolean(true);
    }
    return YCPBoolean(false);
}

YCPValue alsaGetCardName(int card_id)
{
    if(card_id>=snd_cards())
    {
	return YCPVoid();
    }

    char* cname;
    snd_card_get_name(card_id, &cname);
    return YCPString(cname);
}
