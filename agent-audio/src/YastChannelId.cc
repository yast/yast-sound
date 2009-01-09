/* ------------------------------------------------------------------------------
 * Copyright (c) 2009 Novell, Inc. All Rights Reserved.
 *
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of version 2 of the GNU General Public License as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program; if not, contact Novell, Inc.
 *
 * To contact Novell about this file by physical or electronic mail, you may find
 * current contact information at www.novell.com.
 * ------------------------------------------------------------------------------
 */

/*
   File:	$Id:$
   Author:	Ladislav Slezák <lslezak@novell.com>
   Summary:     Class for converting Alsa channel name to Yast channel ID and vice versea.
*/

#include "YastChannelId.h"

// ::snprintf
#include <cstdio>
// ::atoi
#include <cstdlib>

// parse "<channel_name>_#<index>#" string
YastChannelId::YastChannelId(const std::string &yastID)
{
    channel_name = yastID;
    channel_index = 0;

    if (yastID.empty())
    {
	return;
    }

    std::string::const_iterator it = yastID.end();

    std::string::const_iterator number_end_it = yastID.end();
    std::string::const_iterator number_begin_it = yastID.end();

    --it;

    if (it == yastID.begin())
    {
	return;
    }

    // no channel index appended
    if (*it != '#')
    {
	return;
    }
    else
    {
	number_end_it = it;
	--it;

	if (it == yastID.begin())
	{
	    return;
	}

	bool digitfound = false;

	for(;it != yastID.begin(); --it)
	{
	    if (!isdigit(*it))
	    {
		break;
	    }
	    else
	    {
		digitfound = true;
	    }
	}

	if (!digitfound)
	{
	    // channel name end with # but no valid index is there
	    return;
	}
	else
	{
	    // no name found
	    if (it == yastID.begin())
	    {
		return;
	    }

	    if (*it == '#')
	    {
		number_begin_it = it;
		number_begin_it++;

		--it;

		if (it == yastID.begin())
		{
		    return;
		}

		if (*it == '_')
		{
		    channel_name = std::string(yastID.begin(), it);

		    std::string channel_index_str(number_begin_it, number_end_it);
		    channel_index = ::atoi(channel_index_str.c_str());
		}
	    }
	}
    }
}

std::string YastChannelId::asString()
{
    if (channel_index == 0)
    {
	return channel_name;
    }

    // add channel index if it's greater than zero
    std::string ret(channel_name);

    // add index
    char buffer[16];
    ::snprintf(buffer, sizeof(buffer), "_#%u#", channel_index);

    ret += buffer;

    return ret;
}

