#!/bin/bash

DOTFILES_DIR="$HOME/dotfiles"
CONFIG_DIR="$HOME/.config"

mkdir -p "$DOTFILES_DIR/config"
mkdir -p "$DOTFILES_DIR/wallpapers"

copy_config() {
  APP_NAME=$1
  if [ -d "$CONFIG_DIR/$APP_NAME" ]; then
    echo "Backing up $APP_NAME..."
    rm -rf "$DOTFILES_DIR/config/$APP_NAME"
    cp -r "$CONFIG_DIR/$APP_NAME" "$DOTFILES_DIR/config/"
  else
    echo "Warning: $APP_NAME config not found."
  fi
}

copy_config "hypr"
copy_config "waybar"
copy_config "rofi"
copy_config "kitty"
copy_config "btop"
copy_config "anyrun"
copy_config "wlogout"

copy_config "doom"
copy_config "nvim"
copy_config "gtk-3.0"
copy_config "gtk-4.0"
copy_config "qt5ct"
copy_config "qt6ct"
copy_config "nwg-look"

mkdir -p "$DOTFILES_DIR/config/vesktop"
if [ -f "$CONFIG_DIR/vesktop/settings.json" ]; then
  cp "$CONFIG_DIR/vesktop/settings.json" "$DOTFILES_DIR/config/vesktop/"
fi
if [ -d "$CONFIG_DIR/vesktop/themes" ]; then
  cp -r "$CONFIG_DIR/vesktop/themes" "$DOTFILES_DIR/config/vesktop/"
fi

if [ -d "$HOME/Pictures/wallpapers/tokyonight-wallpapers" ]; then
  cp -r "$HOME/Pictures/wallpapers/tokyonight-wallpapers/"* "$DOTFILES_DIR/wallpapers/"
fi

echo "Collection complete."
