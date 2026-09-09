#!/usr/bin/env bash
# =============================================================
# Groovy – Linux Easy Installer
# Double-click this script in your file manager to install.
# =============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPIMAGE=$(find "$SCRIPT_DIR" -maxdepth 1 -name "*.AppImage" | head -1)

# ── Helpers ────────────────────────────────────────────────────
show_msg() {
  if command -v zenity &>/dev/null; then
    zenity --info --no-wrap --title="Groovy Installer" --text="$1" 2>/dev/null || true
  elif command -v kdialog &>/dev/null; then
    kdialog --title "Groovy Installer" --msgbox "$1" 2>/dev/null || true
  else
    echo "$1"
  fi
}

show_error() {
  if command -v zenity &>/dev/null; then
    zenity --error --no-wrap --title="Groovy Installer" --text="$1" 2>/dev/null || true
  elif command -v kdialog &>/dev/null; then
    kdialog --title "Groovy Installer" --error "$1" 2>/dev/null || true
  else
    echo "ERROR: $1" >&2
  fi
}

# ── Check AppImage exists ──────────────────────────────────────
if [ -z "$APPIMAGE" ]; then
  show_error "No AppImage file found in the same folder as this script.\n\nMake sure Groovy-*-linux-x86_64.AppImage is in the same directory."
  exit 1
fi

APPIMAGE_NAME="$(basename "$APPIMAGE")"

# ── Mark AppImage as executable ────────────────────────────────
chmod +x "$APPIMAGE"

# ── Ask where to install ───────────────────────────────────────
INSTALL_DIR="$HOME/.local/bin"
ICONS_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
APPS_DIR="$HOME/.local/share/applications"

mkdir -p "$INSTALL_DIR" "$ICONS_DIR" "$APPS_DIR"

# Copy AppImage to ~/.local/bin/groovy
DEST="$INSTALL_DIR/Groovy.AppImage"
cp -f "$APPIMAGE" "$DEST"
chmod +x "$DEST"

# ── Create .desktop entry (enables app menu + double-click) ───
ICON_PATH="$ICONS_DIR/groovy.png"

# Try to extract icon from AppImage
if [ -f "$SCRIPT_DIR/groovy.png" ]; then
  cp "$SCRIPT_DIR/groovy.png" "$ICON_PATH"
else
  # Extract from AppImage if possible
  "$DEST" --appimage-extract usr/share/icons/hicolor/256x256/apps/groovy.png &>/dev/null && \
    mv squashfs-root/usr/share/icons/hicolor/256x256/apps/groovy.png "$ICON_PATH" && \
    rm -rf squashfs-root || true
fi

ICON_ARG="$ICON_PATH"
[ ! -f "$ICON_PATH" ] && ICON_ARG="application-x-executable"

cat > "$APPS_DIR/groovy.desktop" << EOF
[Desktop Entry]
Name=Groovy
Comment=Stream music from YouTube Music
Exec=$DEST
Icon=$ICON_ARG
Terminal=false
Type=Application
Categories=Audio;Music;Player;AudioVideo;
Keywords=music;streaming;youtube;
StartupWMClass=groovy
EOF

chmod +x "$APPS_DIR/groovy.desktop"

# Refresh desktop database
if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "$APPS_DIR" &>/dev/null || true
fi
if command -v gtk-update-icon-cache &>/dev/null; then
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" &>/dev/null || true
fi

show_msg "✅ Groovy was installed successfully!\n\nYou can now:\n• Find it in your Applications menu (under Music)\n• Launch it by double-clicking the AppImage directly\n\nInstalled to: $DEST"
