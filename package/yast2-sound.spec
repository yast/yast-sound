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

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#


Name:           yast2-sound
Version:        4.1.1
Release:        0
Summary:        YaST2 - Sound Configuration
License:        GPL-2.0-or-later
Group:          System/YaST
Url:            https://github.com/yast/yast-sound

Source0:        %{name}-%{version}.tar.bz2

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
Requires:       yast2-ruby-bindings >= 1.0.0

Provides:       yast2-agent-audio
Provides:       yast2-agent-audio-devel
Provides:       yast2-config-sound
Provides:       y2c_snd
Provides:       y2t_snd
Provides:       y2t_sndd
Provides:       yast2-trans-sound
Provides:       yast2-trans-soundd
Provides:       y2c_sparc
Provides:       y2c_sprc
Provides:       y2d_snd
Provides:       yast2-db-sound

Obsoletes:      yast2-agent-audio
Obsoletes:      yast2-agent-audio-devel
Obsoletes:      yast2-config-sound
Obsoletes:      y2c_snd
Obsoletes:      y2t_snd
Obsoletes:      y2t_sndd
Obsoletes:      yast2-trans-sound
Obsoletes:      yast2-trans-soundd
Obsoletes:      y2c_sparc
Obsoletes:      y2c_sprc
Obsoletes:      y2d_snd
Obsoletes:      yast2-db-sound
Obsoletes:      yast2-sound-devel-doc

# XXX: SLE-12 build packages for x86 and s390, but no runnable kernel, so
# this package cannot be build here. Remove when SLE stop doing it
%if !0%{?is_opensuse}
ExcludeArch:    %ix86 s390
%endif

%description
This package contains the YaST2 component for sound card configuration.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install
rm -rf %{buildroot}/%{yast_plugindir}/libpy2ag_audio.la
%yast_metainfo

%post
# rename the config file to the new modprobe schema
if test -e /etc/modprobe.d/sound; then
    mv -f /etc/modprobe.d/sound /etc/modprobe.d/50-sound.conf
fi

%files
%{yast_yncludedir}
%{yast_clientdir}
%{yast_desktopdir}
%{yast_metainfodir}
%{yast_ybindir}
%{yast_moduledir}
%{yast_schemadir}
# database
%{yast_ydatadir}
# agents
%{yast_plugindir}
%{yast_scrconfdir}
%{yast_icondir}
%doc %{yast_docdir}
%license COPYING

%changelog
