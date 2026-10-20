
# 🌌 My Hyprland Dotfiles

My personal configuration files for Arch Linux running **Hyprland** with a **Tokyo Night** theme.

## 📦 Structure

- **Hyprland**: Window manager configuration (`.config/hypr`)
- **Waybar**: Status bar setup with auto-hide script
- **Rofi**: App launcher, clipboard manager, and power menu scripts
- **Kitty**: Terminal emulator configuration
- **Neovim**: LazyVim setup
- **Doom Emacs**: Private configuration
- **Scripts**: Various helper scripts (wallpapers, audio, etc.)

## 🚀 Installation

1. **Clone the repository:**

   ```bash
   git clone [https://github.com/YOUR_USERNAME/dotfiles.git](https://github.com/YOUR_USERNAME/dotfiles.git) ~/dotfiles
   cd ~/dotfiles

2. **Run the installation script:**

```bash
chmod +x install.sh
./install.sh

```

*This script will install necessary packages (using `yay`), fonts, and link configuration files.*
3. **Restart:**
Restart Hyprland or reboot your system.

## 💻 Multiple machines

One config for the desktop and the laptop. Machine-specific settings (monitors,
GPU environment, laptop extras) live in `config/hypr/hosts/<hostname>.lua`;
any machine without its own file uses `hosts/default.lua` (laptop with
integrated graphics, built-in `eDP-1` screen). Waybar adapts at launch
(`bars.sh`): GPU stats only with NVIDIA, battery/brightness only where present.

To give a machine its own profile: `cp config/hypr/hosts/default.lua config/hypr/hosts/$(hostnamectl hostname).lua`
and edit it. Check a profile without switching: `HYPR_HOST=<name> Hyprland --verify-config`.

Updating another machine: `git pull`, then `./install.sh` (installs missing
packages and links new configs), then log out and back in.

## 🛠️ Credits & Resources

Special thanks to the creators of the awesome tools and assets used in this setup:

- **Wallpapers**: [atraxsrc/tokyonight-wallpapers](https://github.com/atraxsrc/tokyonight-wallpapers) - A beautiful collection of Tokyo Night themed wallpapers.
- **Waybar Auto-Hide**: [Zephirus2/waybar_auto_hide](https://www.google.com/search?q=https://github.com/Zephirus2/waybar_auto_hide) - A Rust utility to automatically hide Waybar.
- **Theme**: Tokyo Night

```

```
