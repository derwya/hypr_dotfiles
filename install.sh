#!/bin/bash

DOTFILES_DIR="$HOME/dotfiles"
CONFIG_DIR="$HOME/.config"
BIN_DIR="$HOME/.local/bin"

if ! command -v yay &>/dev/null; then
  echo "Installing yay..."
  sudo pacman -S --needed git base-devel
  git clone https://aur.archlinux.org/yay.bin.git
  cd yay-bin
  makepkg -si
  cd ..
  rm -rf yay-bin
fi

echo "Installing System Packages..."
yay -S --needed \
  hyprland hyprpaper hyprlock hypridle xdg-desktop-portal-hyprland \
  waybar rofi-wayland swaync \
  kitty btop anyrun-git \
  wl-clipboard cliphist grim slurp \
  network-manager-applet brightnessctl \
  nwg-look nwg-displays \
  polkit-gnome \
  pacman-contrib \
  rustup

echo "Installing Apps..."
yay -S --needed \
  neovim zen-browser-bin vesktop-bin spotify \
  emacs ripgrep fd lazygit

echo "Installing Fonts..."
yay -S --needed \
  ttf-jetbrains-mono-nerd \
  ttf-font-awesome \
  noto-fonts \
  noto-fonts-cjk \
  noto-fonts-emoji \
  ttf-fira-sans \
  ttf-fira-code

echo "Installing Theme Dependencies..."
yay -S --needed \
  qt5ct qt6ct kvantum \
  gtk3 gtk4 \
  xsettingsd

create_link() {
  SRC="$DOTFILES_DIR/config/$1"
  DEST="$CONFIG_DIR/$1"

  if [ -d "$SRC" ] || [ -f "$SRC" ]; then
    mkdir -p "$(dirname "$DEST")"
    if [ -e "$DEST" ]; then
      echo "Backing up existing $DEST to $DEST.bak"
      mv "$DEST" "$DEST.bak"
    fi
    ln -s "$SRC" "$DEST"
    echo "Linked $1"
  fi
}

mkdir -p "$CONFIG_DIR"

create_link "hypr"
create_link "waybar"
create_link "rofi"
create_link "kitty"
create_link "btop"
create_link "anyrun"
create_link "nvim"
create_link "doom"
create_link "gtk-3.0"
create_link "gtk-4.0"
create_link "qt5ct"
create_link "qt6ct"
create_link "vesktop"

mkdir -p "$HOME/Pictures/wallpapers/tokyonight-wallpapers"
ln -sf "$DOTFILES_DIR/wallpapers/"* "$HOME/Pictures/wallpapers/tokyonight-wallpapers/"

mkdir -p "$BIN_DIR"
RUST_PROJECT="$DOTFILES_DIR/waybar_auto_hide"

if [ -d "$RUST_PROJECT" ]; then
  echo "Found waybar_auto_hide project..."

  COMPILED_BIN="$RUST_PROJECT/target/release/waybar_auto_hide"

  if [ -f "$COMPILED_BIN" ]; then
    echo "Found compiled binary. Installing to $BIN_DIR..."
    cp "$COMPILED_BIN" "$BIN_DIR/waybar_auto_hide"
  else
    echo "Binary not found. Compiling from source..."
    if ! command -v cargo &>/dev/null; then
      rustup default stable
    fi
    cd "$RUST_PROJECT"
    cargo build --release
    cp "target/release/waybar_auto_hide" "$BIN_DIR/waybar_auto_hide"
  fi

  chmod +x "$BIN_DIR/waybar_auto_hide"
  echo "waybar_auto_hide installed."
else
  echo "waybar_auto_hide folder not found in dotfiles."
fi

chmod +x "$CONFIG_DIR/hypr/scripts/"*.sh 2>/dev/null
chmod +x "$CONFIG_DIR/waybar/scripts/"*.sh 2>/dev/null
chmod +x "$CONFIG_DIR/rofi/"*.sh 2>/dev/null

gsettings set org.gnome.desktop.interface gtk-theme "Tokyonight-Dark"
gsettings set org.gnome.desktop.interface icon-theme "Tokyonight-Dark"
gsettings set org.gnome.desktop.interface font-name "JetBrainsMono Nerd Font 10"
export QT_QPA_PLATFORMTHEME=qt6ct

echo "Installation complete. Please reboot."
