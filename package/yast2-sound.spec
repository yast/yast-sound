#
# spec file for package yast2-sound
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-sound
Version:        3.1.2
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:	        System/YaST
License:        GPL-2.0+
BuildRequires:	alsa-devel gcc-c++ doxygen perl-XML-Writer update-desktop-files yast2 yast2-core-devel yast2-testsuite kernel-default ruby libtool
BuildRequires:  yast2-devtools >= 3.0.6

# Fixed handling of Kernel modules loaded on boot
Requires:	yast2 >= 3.1.3
Requires:	alsa

Provides:	yast2-config-sound yast2-agent-audio yast2-agent-audio-devel
Obsoletes:	yast2-config-sound yast2-agent-audio yast2-agent-audio-devel
Provides:	yast2-trans-sound yast2-trans-soundd y2c_snd y2t_snd y2t_sndd
Obsoletes:	yast2-trans-sound yast2-trans-soundd y2c_snd y2t_snd y2t_sndd
Provides:	y2c_sparc y2c_sprc yast2-db-sound y2d_snd
Obsoletes:	y2c_sparc y2c_sprc yast2-db-sound y2d_snd

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	YaST2 - Sound Configuration

%description
This package contains the YaST2 component for sound card configuration.


%package devel-doc
Requires:       yast2-sound = %version
Group:          System/YaST
Summary:        YaST2 - Sound Configuration - Development Documentation

%description devel-doc
This package contains development documentation for using the API
provided by yast2-sound package.


%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install

rm -rf %{buildroot}/%{yast_plugindir}/libpy2ag_audio.la


%post
# rename the config file to the new modprobe schema
if test -e /etc/modprobe.d/sound; then
    mv -f /etc/modprobe.d/sound /etc/modprobe.d/50-sound.conf
fi


%files
%defattr(-,root,root)

# sound
%dir %{yast_yncludedir}/sound
%{yast_yncludedir}/sound/*.rb
%{yast_clientdir}/sound*.rb
%{yast_clientdir}/joystick.rb
%{yast_desktopdir}/sound.desktop
%{yast_desktopdir}/joystick.desktop
%{yast_ybindir}/copyfonts
%{yast_ybindir}/alsadrivers
%{yast_ybindir}/joystickdrivers
%{yast_moduledir}/Sound.*
%{yast_moduledir}/Joystick.*
%{yast_moduledir}/PulseAudio.*
%{yast_schemadir}/autoyast/rnc/sound.rnc

# database
%{yast_ydatadir}/sndcards.yml
%{yast_ydatadir}/alsa_packages.yml

# agents
%{yast_plugindir}/libpy2ag_audio.so*
%{yast_scrconfdir}/*.scr

%dir %{yast_docdir}
%doc %{yast_docdir}/README
%doc %{yast_docdir}/COPYING

%files devel-doc
%doc %{yast_docdir}/autodocs
%doc %{yast_docdir}/agent-audio
%doc %{yast_docdir}/joystick-db.txt
%doc %{yast_docdir}/sound_db.md

