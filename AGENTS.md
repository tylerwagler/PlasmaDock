# PlasmaDock Development Guide

## Overview
PlasmaDock is a KDE Plasma 6 task manager applet with macOS-style dock zoom animation. Built with C++23, Qt 6.4+, and KDE Frameworks 6.0+. Targets Plasma 6.6+.

## Project Structure
```
/ (root)
├── CMakeLists.txt           # Main build file
├── plugin/                  # Plugin source code
│   ├── CMakeLists.txt       # Plugin build configuration
│   ├── backend.h/cpp        # Core backend logic
│   ├── smartlauncheritem.h/cpp  # Smart launcher item delegate
│   └── plugin.cpp           # Plugin entry point
├── package/                 # Plasma package contents
│   ├── metadata.json        # Plugin metadata
│   └── contents/            # QML UI components
│       ├── ui/              # QML components
│       └── skins/           # Visual themes (legacy, may be removed)
├── layout-templates/        # Pre-configured panel layouts
└── README.md                # User-facing documentation
```

## Build System
The project uses CMake with Qt 6 and KDE Frameworks 6.

### Standard Build Commands
```bash
# Create build directory
mkdir -p build && cd build

# Configure build (Debug)
cmake .. -DCMAKE_BUILD_TYPE=Debug

# Build
make -j$(nproc)

# Install (to local prefix for testing)
make install DESTDIR=$(pwd)/install

# Clean build
make clean
```

### Development Workflow
For iterative development:
```bash
# After initial build
cd build
make -j$(nproc)   # Rebuild changed targets
# Copy updated plugin to Plasma components directory:
cp libplasmadockplugin.so ~/.local/lib/qt6/qml/org/plasmadock/

# Reload to test changes
plasmashell --replace
```

### Testing
The project currently lacks automated tests. To validate changes:
1. Build and install as above
2. Restart Plasma Shell to load the plugin:
   ```bash
   plasmashell --replace
   ```
3. Add the PlasmaDock widget to a panel:
   - Right-click on panel → "Add Widgets"
   - Find "PlasmaDock" and add it to your panel
4. Verify functionality in the panel

### Single Test Execution
No test framework is configured. When tests are added:
```bash
# Assuming CTest is used
ctest -R <test_name>  # Run specific test by regex
ctest -V              # Verbose output
```

## Architecture

### C++ Plugin (`plugin/`)
Compiled as `libplasmadockplugin.so`, registered as a Qt6 QML module (`org.plasmadock`).

- **`backend.h/cpp`** — Core task manager logic. Handles jump list actions, places, recent documents, KActivities integration. Exposed to QML via `QML_ELEMENT`.
- **`smartlauncherbackend.h/cpp`** — Monitors D-Bus for app badge counts, progress bars, and urgency flags. Integrates with NotificationManager and Unity Launcher API.
- **`smartlauncheritem.h/cpp`** — Per-launcher QML item wrapping the shared SmartLauncher::Backend singleton (`std::weak_ptr`).
- **`plugin.cpp`** — QmlExtensionPlugin entry point.

### QML Frontend (`package/contents/ui/`)
The UI layer.

- **`main.qml`** — Root plasmoid. Handles panel transparency, zoom state tracking, panel rotation.
- **`Task.qml`** — Individual task delegate with zoom animation, mouse events, tooltips.
- **`TaskList.qml`** — Task list container using Repeater.
- **`ContextMenu.qml`** — Right-click context menu with recent/frequent actions.
- **`ToolTipInstance.qml`** — Task preview tooltips.
- **`ConfigAppearance.qml` / `ConfigBehavior.qml`** — Settings panels.
- **`code/LayoutMetrics.js`, `code/TaskTools.js`** — Sizing calculations and task utilities.

### Layout Templates (`layout-templates/`)
Pre-configured panel layouts including the "Plasma Dock" dock-style layout.

## Code Style Guidelines

### Language Standards
- C++23 (as set in CMakeLists.txt)
- Qt 6.4+ and KDE Frameworks 6.0+
- Follow KDE Frameworks coding style: https://community.kde.org/Policies/Kdelibs_Coding_Style

### Formatting
- Indentation: 4 spaces (no tabs)
- Line length: 100 characters maximum
- Braces: Allman style (brace on new line for functions, classes, namespaces; same line for control blocks)
- Pointer/reference: `Type* ptr` (space after type, before pointer)
- Includes: System/Qt/KDE first, then local, sorted alphabetically within groups

### File Headers
Every file must include SPDX header:
```cpp
/*
    SPDX-FileCopyrightText: <year> <author email>
    SPDX-License-Identifier: GPL-2.0-or-later
```
Update year and author as appropriate.

### Naming Conventions
- Classes/Structs: PascalCase (e.g., `Backend`)
- Functions/Methods: camelCase (e.g., `jumpListActions`)
- Variables: camelCase (e.g., `m_actionGroup` for member variables)
- Enums: PascalCase, values: ALL_CAPS (e.g., `MiddleClickAction::None`)
- Namespaces: camelCase
- QML elements: CamelCase matching C++ class names
- Constants: `kConstantName` or `ALL_CAPS` for macros

### Imports/Includes
Order:
1. C system headers
2. C++ standard library
3. Qt modules
4. KDE Frameworks
5. Plasma libraries
6. Local project headers
Within each group, sort alphabetically.

Example:
```cpp
#include <QAction>
#include <QJsonArray>
#include <KLocalizedString>
#include <KService>
#include "backend.h"
#include "log_settings.h"
```

### Types
- Use Qt types where appropriate (`QString`, `QUrl`, `QVariant`)
- Prefer `qint64`, `quint64` for explicit size integers
- Use `Q_ENUM` for enums exposed to QML
- For flags, use `Q_FLAG` with `Q_DECLARE_FLAGS`

### Error Handling
- Check validity of objects returned from factories (e.g., `KService::Ptr`)
- Validate URLs and file paths before use
- Use `qCWarning()` and `qCDebug()` for logging with category `WAVETASK_DEBUG`
- Return early on invalid conditions (guard clauses)
- For QML-invokable methods, return appropriate empty values on error

### Memory Management
- Use parent-child QObject ownership where possible
- For dynamically allocated QObjects without parent, ensure explicit deletion
- Prefer stack allocation and smart pointers (`std::unique_ptr`) for non-QObject resources
- Avoid raw owning pointers; use `QPointer` for weakly referenced QObjects

### Qt Specifics
- Mark QML-exposed methods with `Q_INVOKABLE`
- Use `QML_ELEMENT` or `QML_NAMED_ELEMENT` for QML types
- Use `Q_GADGET` for non-QObject types needed in QML
- Prefer Qt containers (`QList`, `QStringList`) over STL when interacting with Qt APIs
- Use `QLatin1String` for string literals compared to Qt strings
- Use `QStringLiteral` for constant strings

### KDE Specifics
- Use `KLocalizedString` for all user-visible text (`i18n()`, `i18nc()`, `i18ncp()`)
- Use `KConfigWatcher` for configuration changes
- Use `KPluginFactory`/`K_PLUGIN_CLASS_WITH_JSON` for plugins (though this uses manual registration)
- Log with categories defined via `ECMQtDeclareLoggingCategory`
- Use `KIconUtils::loadIconIconFromTheme` or `QIcon::fromTheme()` for theme icons

### QML/JavaScript
- Follow Qt Quick coding conventions
- Use `pragma Singleton` for singleton objects
- Property names: camelCase
- Signal names: camelCase
- Use `Qt.binding()` for property bindings when necessary
- Prefer property aliases over manual getters/setters when possible
- Use `Console.log()` for debugging (removed in production)

### Comments
- Use // for single-line comments
- Use /* */ for file headers and temporary disabling code
- Explain why, not what
- Keep comments updated with code changes
- TODOs should include context: `// TODO: <username> - explain`

### Version Control
- Commit messages: Conventional Commits format
  - `feat`: new feature
  - `fix`: bug fix
  - `docs`: documentation changes
  - `style`: formatting, missing semicolons, etc.
  - `refactor`: code restructuring
  - `perf`: performance improvements
  - `test`: adding or correcting tests
  - `chore`: build process, tooling updates
- Reference issues: `Fixes #123` or `Related to #456`

## Key Dependencies
- Qt6 (Core, DBus, Qml, Quick, Widgets)
- KF6 (CoreAddons, I18n, Service, WindowSystem, Config, ConfigWidgets, Notifications, KIO, Bookmarks, Solid)
- Plasma (Plasma, PlasmaActivities, PlasmaActivitiesStats)
- LibTaskManager, LibNotificationManager
- KSysGuard

## Additional Notes
- The plugin integrates with KDE Activities via `PlasmaActivities::Consumer`
- Uses KIO for launching applications
- Manages jump lists and recent documents via KService
- Configuration is handled through KConfigXT (`kactivitymanagerd_plugins_settings.kcfg`)

## Troubleshooting Build Issues
1. Missing dependencies: Install required packages:
   ```bash
   # On Fedora/RHEL
   sudo dnf install extra-cmake-modules qt6-qtdeclarative kf6-kactivities kf6-kio kf6-knotifications kf6-kio kf6-bookmarks kf6-plasma plasma-activities ksysguard
   
   # On Ubuntu/Debian
   sudo apt install extra-cmake-modules qt6-base-dev libkf6activities6 libkf6i18n-dev libkf6service-dev libkf6config-dev libkf6configwidgets-dev libkf6notifications-dev libkf6kio-dev libkf6bookmarks-dev plasma-dev libksysguard-dev
   ```
2. Version mismatches: Ensure Qt 6.4+ and KF6 6.0+ are installed
3. QML module not found: Verify `qt_add_qml_module` is working and QML imports are correct

## Packaging

### Automated Builds
GitHub Actions automatically builds `.deb` (Ubuntu/Debian) and `.rpm` (Fedora/openSUSE) packages when a new release is published:
- See `.github/workflows/build.yml` for the CI/CD configuration
- Download packages from the GitHub Releases page

### Manual Packaging

#### Debian/Ubuntu
```bash
# Install build dependencies
sudo apt install build-essential cmake extra-cmake-modules \
  qt6-base-dev qt6-base-private-dev qt6-declarative-dev \
  libkf6coreaddons-dev libkf6i18n-dev libkf6service-dev \
  libkf6windowsystem-dev libkf6config-dev libkf6configwidgets-dev \
  libkf6notifications-dev libkf6kio-dev libkf6bookmarks-dev \
  libkf6itemmodels-dev libplasma-dev plasma-activities-dev \
  plasma-activities-stats-dev plasma-workspace-dev \
  libksysguard-dev kwin-dev libepoxy-dev libdrm-dev

# Build DEB package
dpkg-buildpackage -us -uc
```

#### Fedora
```bash
# Install build dependencies
sudo dnf install gcc-c++ cmake extra-cmake-modules \
  qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel \
  kf6-ki18n-devel kf6-kservice-devel kf6-kwindowsystem-devel \
  kf6-kconfig-devel kf6-kconfigwidgets-devel kf6-knotifications-devel \
  kf6-kio-devel kf6-kcoreaddons-devel kf6-kitemmodels-devel \
  libplasma-devel plasma-activities-devel plasma-activities-stats-devel \
  plasma-workspace-devel libksysguard-devel kwin-devel libepoxy-devel libdrm-devel

# Build RPM package (requires spec file)
rpmbuild -ba plasmadock.spec
```
