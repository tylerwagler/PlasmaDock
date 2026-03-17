%undefine _cmake_in_source_build

Name:           plasmadock
Version:        6.6.0
Release:        1%{?dist}
Summary:        Reusable Qt6 QML Task Manager Plugin for Plasma 6

License:        GPL-2.0-or-later
URL:            https://github.com/vickoc911/org.vicko.plasmadock
Source0:        %{url}/archive/refs/heads/main.tar.gz#/%{name}-%{version}.tar.gz

BuildRequires:  gcc-c++
BuildRequires:  fdupes
BuildRequires:  cmake

BuildRequires:  extra-cmake-modules

BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtbase-private-devel
BuildRequires:  qt6-declarative-devel

BuildRequires:  kf6-ki18n-devel
BuildRequires:  kf6-kservice-devel
BuildRequires:  kf6-kwindowsystem-devel
BuildRequires:  kf6-kconfig-devel
BuildRequires:  kf6-kconfigwidgets-devel
BuildRequires:  kf6-knotifications-devel
BuildRequires:  kf6-kio-devel
BuildRequires:  kf6-kcoreaddons-devel
BuildRequires:  kf6-kitemmodels-devel

BuildRequires:  libplasma-devel
BuildRequires:  plasma-activities-devel
BuildRequires:  plasma-activities-stats-devel
BuildRequires:  plasma-workspace-devel

BuildRequires:  libksysguard-devel
BuildRequires:  libepoxy-devel
BuildRequires:  libdrm-devel

BuildRequires:  cmake(LibTaskManager)
BuildRequires:  cmake(LibNotificationManager)

Provides:       qt6qmlimport(org.vicko.plasmadock.1) = %{version}
Provides:       qt6qmlimport(org.vicko.plasmadock) = %{version}

%description
Plasmoid plasmadock Qt6 QML Task Manager plugin for Plasma 6 environments with zoom.

%prep
%autosetup -p1 -n org.vicko.plasmadock-main

%build
export CXXFLAGS="%{optflags} -I%{_vpath_builddir}/plugin"

%cmake \
  -DBUILD_TESTING=OFF \
  -DKDE_INSTALL_USE_QT_SYS_PATHS=ON

%cmake_build

%install
%cmake_install
%fdupes %{buildroot}

%files
%dir %{_libdir}/qt6/qml/org/vicko
%{_libdir}/qt6/qml/org/vicko/plasmadock/

%{_datadir}/plasma/plasmoids/org.vicko.plasmadock/

%dir %{_datadir}/plasma/layout-templates
%{_datadir}/plasma/layout-templates/org.vicko.plasmadock.panel/

%changelog
* Tue Mar 17 2026 Tyler Wagler <tyler.wagler@elytrondefense.com> - 6.6.0-3
- Rename from wavetask to plasmadock

* Sat Mar 14 2026 Tyler Wagler <tyler.wagler@elytrondefense.com> - 6.6.0-2
- Strip skin system, fix clipping, comprehensive code audit

* Wed Mar 11 2026 Victor Calles - 6.6.0-1
- Initial COPR build
