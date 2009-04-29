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
   File:	$Id$
   Author:	Ladislav Slezák <lslezak@novell.com>
   Summary:     Class for converting Alsa channel name to Yast channel ID and vice versea.
*/

#include <string>

class YastChannelId
{
    public:

	YastChannelId() : channel_name(), channel_index(0) {}
	YastChannelId(const char* alsa_name, unsigned alsa_index) : channel_name(alsa_name), channel_index(alsa_index) {}
	YastChannelId(const std::string &YastID);

	std::string name() {return channel_name;}
	unsigned index() {return channel_index;}

	std::string asString();

    private:

	std::string channel_name;
	unsigned channel_index;
};

