# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PlasmaDock is a KDE Plasma 6 task manager applet with macOS-style dock zoom animation. Built with C++23, Qt 6.4+, and KDE Frameworks 6.0+. Targets Plasma 6.6+.

## Build Commands

```bash
# Configure (from repo root, build artifacts go to current directory)
cmake . -DCMAKE_BUILD_TYPE=Debug

# Build
make -j$(nproc)

# Install to local prefix for testing
make install DESTDIR=$(pwd)/install

# Iterative dev: copy rebuilt plugin
cp plugin/libplasmadockplugin.so ~/.local/lib/qt6/qml/org/plasmadock/

# Reload to test changes
plasmashell --replace
```

No automated test framework is configured. Testing is manual: build, install, restart plasmashell, add the "Wave Task Manager" widget to a panel.

## Architecture

**C++ Plugin** (`plugin/`): Compiled as `libplasmadockplugin.so`, registered as a Qt6 QML module (`org.vicko.plasmadock`).

- `backend.h/cpp` — Core task manager logic. Handles jump list actions, places, recent documents, KActivities integration. Exposed to QML via `QML_ELEMENT`.
- `smartlauncherbackend.h/cpp` — Monitors D-Bus for app badge counts, progress bars, and urgency flags. Integrates with NotificationManager and Unity Launcher API.
- `smartlauncheritem.h/cpp` — Per-launcher QML item wrapping the shared SmartLauncher::Backend singleton (`std::weak_ptr`).
- `plugin.cpp` — QmlExtensionPlugin entry point.

**QML Frontend** (`package/contents/ui/`): The UI layer.

- `main.qml` — Root plasmoid. Handles panel transparency, zoom state tracking, panel rotation.
- `Task.qml` — Individual task delegate with zoom animation, mouse events, tooltips.
- `TaskList.qml` — Task list container using Repeater.
- `ContextMenu.qml` — Right-click context menu with recent/frequent actions.
- `ToolTipInstance.qml` — Task preview tooltips.
- `ConfigAppearance.qml` / `ConfigBehavior.qml` — Settings panels.
- `code/LayoutMetrics.js`, `code/TaskTools.js` — Sizing calculations and task utilities.

**Layout Templates** (`layout-templates/`): Pre-configured panel layouts.

## Code Style

- KDE Frameworks coding style. 4-space indent, 100-char line limit.
- Allman braces for functions/classes; same-line braces for control blocks.
- Include order: C system → C++ stdlib → Qt → KDE Frameworks → Plasma → local headers (alphabetical within groups).
- Every file needs SPDX header (`GPL-2.0-or-later`).
- PascalCase for classes, camelCase for methods/variables, `m_` prefix for members.
- Use `i18n()` for user-visible strings, `qCWarning(WAVETASK_DEBUG)` / `qCDebug(WAVETASK_DEBUG)` for logging.
- Commit messages: Conventional Commits (`feat:`, `fix:`, `docs:`, etc.).

## Key Dependencies

Qt6 (Core, DBus, Qml, Quick, Widgets), KF6 (CoreAddons, I18n, Service, WindowSystem, Config, ConfigWidgets, Notifications, KIO), Plasma (Plasma, PlasmaActivities, PlasmaActivitiesStats), LibTaskManager, LibNotificationManager, KSysGuard.

## Packaging

- **Fedora**: RPM spec at `org.vicko.plasmadock_fedora.spec`, published via COPR.
- **Debian/Ubuntu**: Packaging in `debian/`. Build with `dpkg-buildpackage -us -uc` or `debuild`.

## Build Dependencies (install if missing)

```bash
# Debian/Ubuntu (24.04+ for Plasma 6)
sudo apt install build-essential cmake extra-cmake-modules \
  qt6-base-dev qt6-base-private-dev qt6-declarative-dev \
  libkf6coreaddons-dev libkf6i18n-dev libkf6service-dev \
  libkf6windowsystem-dev libkf6config-dev libkf6configwidgets-dev \
  libkf6notifications-dev libkf6kio-dev libkf6bookmarks-dev \
  libkf6itemmodels-dev libplasma-dev plasma-activities-dev \
  plasma-activities-stats-dev plasma-workspace-dev \
  libksysguard-dev kwin-dev libepoxy-dev libdrm-dev

# Fedora/RHEL
sudo dnf install gcc-c++ cmake extra-cmake-modules \
  qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel \
  kf6-ki18n-devel kf6-kservice-devel kf6-kwindowsystem-devel \
  kf6-kconfig-devel kf6-kconfigwidgets-devel kf6-knotifications-devel \
  kf6-kio-devel kf6-kcoreaddons-devel kf6-kitemmodels-devel \
  libplasma-devel plasma-activities-devel plasma-activities-stats-devel \
  plasma-workspace-devel libksysguard-devel kwin-devel libepoxy-devel libdrm-devel
```
