# PlasmaDock

[![GitHub Release](https://img.shields.io/github/v/release/tylerwagler/PlasmaDock)](https://github.com/tylerwagler/PlasmaDock/releases)
[![Build Status](https://github.com/tylerwagler/PlasmaDock/actions/workflows/build.yml/badge.svg)](https://github.com/tylerwagler/PlasmaDock/actions)
[![License: GPL-2.0-or-later](https://img.shields.io/badge/License-GPL--2.0--or--later-blue.svg)](LICENSE)

A modern KDE Plasma 6 task manager with macOS-style dock zoom animation, smart launcher badges, and advanced window management features.

![PlasmaDock Screenshot](screenshot/plasmadock_1280.webp)

## Features

- 🎨 **macOS-style dock zoom** - Smooth Gaussian curve zoom effect when hovering over icons
- 🔄 **Icon mirroring** - Optional reflection effect for a premium look
- 🎯 **Smart launcher** - Badge counts, progress bars, and urgency indicators from Unity Launcher API
- 🖥️ **KDE Activities integration** - Full support for Plasma activities and virtual desktops
- ⚙️ **Highly configurable** - Customize icon size, zoom percentage, hover effects, and more
- 🎯 **Drag-and-drop reordering** - Intuitively rearrange tasks
- 📦 **Panel templates** - Pre-configured dock-style panel layouts

## Requirements

- **Plasma 6.6+** (required for direct task manager library access)
- Qt 6.4+
- KDE Frameworks 6.0+

> **Note:** For Plasma 6.5 and earlier, see the [original repository](https://github.com/vickoc911/org.kde.plasma.plasmadock) which supports older versions.

## Installation

### From GitHub Releases (Recommended)

Download the appropriate package for your distribution from the [Releases page](https://github.com/tylerwagler/PlasmaDock/releases):

#### Ubuntu/Debian
```bash
# Download the .deb file from the latest release
wget https://github.com/tylerwagler/PlasmaDock/releases/download/v1.0.0/plasmadock_v1.0.0_amd64.deb

# Install
sudo dpkg -i plasmadock_v1.0.0_amd64.deb
sudo apt install -f  # Fix dependencies if needed
```

#### Fedora
```bash
# Download the .rpm file from the latest release
wget https://github.com/tylerwagler/PlasmaDock/releases/download/v1.0.0/plasmadock_v1.0.0-1.fc40.x86_64.rpm

# Install
sudo dnf install plasmadock_v1.0.0-1.fc40.x86_64.rpm
```

#### openSUSE
```bash
# Download the .rpm file from the latest release
wget https://github.com/tylerwagler/PlasmaDock/releases/download/v1.0.0/plasmadock_v1.0.0-1.x86_64.rpm

# Install
sudo rpm -ivh plasmadock_v1.0.0-1.x86_64.rpm
```

### Manual Installation (from source)

#### Build Dependencies

**Ubuntu/Debian (24.04+):**
```bash
sudo apt install build-essential cmake extra-cmake-modules \
  qt6-base-dev qt6-base-private-dev qt6-declarative-dev \
  libkf6coreaddons-dev libkf6i18n-dev libkf6service-dev \
  libkf6windowsystem-dev libkf6config-dev libkf6configwidgets-dev \
  libkf6notifications-dev libkf6kio-dev libkf6bookmarks-dev \
  libkf6itemmodels-dev libplasma-dev plasma-activities-dev \
  plasma-activities-stats-dev plasma-workspace-dev \
  libksysguard-dev kwin-dev libepoxy-dev libdrm-dev
```

**Fedora/RHEL:**
```bash
sudo dnf install gcc-c++ cmake extra-cmake-modules \
  qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel \
  kf6-ki18n-devel kf6-kservice-devel kf6-kwindowsystem-devel \
  kf6-kconfig-devel kf6-kconfigwidgets-devel kf6-knotifications-devel \
  kf6-kio-devel kf6-kcoreaddons-devel kf6-kitemmodels-devel \
  libplasma-devel plasma-activities-devel plasma-activities-stats-devel \
  plasma-workspace-devel libksysguard-devel kwin-devel libepoxy-devel libdrm-devel
```

#### Build and Install
```bash
# Clone the repository
git clone https://github.com/tylerwagler/PlasmaDock.git
cd PlasmaDock

# Build
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

# Install
sudo make install
```

## Usage

### Adding PlasmaDock to Your Panel

1. **Right-click** on your Plasma panel
2. Select **"Add Widgets"**
3. Search for **"PlasmaDock"**
4. **Drag** it onto your panel

### Using the Panel Template

For a complete dock-style experience:

1. **Right-click** on your panel
2. Select **"Configure Panel"**
3. Go to **"Layout"** tab
4. Select **"Plasma Dock"** from the dropdown
5. Click **"Apply"**

### Configuration

Right-click on the PlasmaDock widget and select **"Configure PlasmaDock"** to customize:

- **Appearance:**
  - Icon size
  - Zoom percentage
  - Enable/disable icon reflections
  - Hover effects

- **Behavior:**
  - Middle-click action (new instance, close, minimize, etc.)
  - Scroll wheel behavior
  - Zoom animation speed

## Development

See [`AGENTS.md`](./AGENTS.md) for detailed development guidelines, build instructions, and code style requirements.

### Quick Start
```bash
# Configure
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Debug

# Build
make -j$(nproc)

# Install for testing
make install DESTDIR=$(pwd)/install

# Test
plasmashell --replace
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Support

If you find this project helpful, consider sponsoring the development:

[![Donate with PayPal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?business=XSHX7RDT74QN2&no_recurring=0&item_name=Support+my+code%3A+If+it+saved+you+time+or+helped%2C+please+consider+donating.+Your+support+keeps+this+Open+Source+project+alive%21&currency_code=USD)

## License

This project is licensed under the GPL-2.0-or-later License - see the [LICENSE](LICENSE) file for details.

## Credits

- **Original author:** Victor Calles (@vickoc911)
- **Current maintainer:** Tyler Wagler (@tylerwagler)
- **Based on:** KDE Plasma 6 Task Manager

## Related Projects

- [Original PlasmaDock](https://github.com/vickoc911/org.kde.plasma.plasmadock) - Original repository with support for Plasma 6.5 and earlier
- [KDE Plasma](https://plasma.kde.org/) - The KDE Plasma desktop environment
