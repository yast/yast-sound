#
# spec file for package yast2-sound
#
# Copyright (c) 2014 SUSE LINUX Products GmbH, Nuernberg, Germany.
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
Version:        3.1.10
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

# XXX: SLE-12 build packages for x86 and s390, but no runnable kernel, so
# this package cannot be build here. Remove when SLE stop doing it
%if !0%{?is_opensuse}
ExcludeArch:    %ix86 s390
%endif

BuildRequires:  alsa-devel
BuildRequires:  doxygen
BuildRequires:  gcc-c++
BuildRequires:  kernel-default
BuildRequires:  libtool
BuildRequires:  perl-XML-Writer
BuildRequires:  ruby
BuildRequires:  update-desktop-files
BuildRequires:  yast2
BuildRequires:  yast2-core-devel
BuildRequires:  yast2-devtools >= 3.1.10
BuildRequires:  yast2-testsuite

# Fixed handling of Kernel modules loaded on boot
Requires:       alsa
# For proc_modules.scr
Requires:       yast2 >= 3.1.180

Provides:       yast2-agent-audio
Provides:       yast2-agent-audio-devel
Provides:       yast2-config-sound
Obsoletes:      yast2-agent-audio
Obsoletes:      yast2-agent-audio-devel
Obsoletes:      yast2-config-sound
Provides:       y2c_snd
Provides:       y2t_snd
Provides:       y2t_sndd
Provides:       yast2-trans-sound
Provides:       yast2-trans-soundd
Obsoletes:      y2c_snd
Obsoletes:      y2t_snd
Obsoletes:      y2t_sndd
Obsoletes:      yast2-trans-sound
Obsoletes:      yast2-trans-soundd
Provides:       y2c_sparc
Provides:       y2c_sprc
Provides:       y2d_snd
Provides:       yast2-db-sound
Obsoletes:      y2c_sparc
Obsoletes:      y2c_sprc
Obsoletes:      y2d_snd
Obsoletes:      yast2-db-sound
Obsoletes:      yast2-sound-devel-doc

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:        YaST2 - Sound Configuration
License:        GPL-2.0+
Group:          System/YaST

%description
This package contains the YaST2 component for sound card configuration.

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
%{yast_desktopdir}/sound.desktop
%{yast_ybindir}/copyfonts
%{yast_ybindir}/alsadrivers
%{yast_moduledir}/Sound.*
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

%changelog
