#!/usr/bin/env bash
# =============================================================
# Groovy â€“ Linux Easy Installer
# Double-click this script in your file manager to install.
# =============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEB_FILE=$(find "$SCRIPT_DIR" -maxdepth 1 -name "*.deb" | head -1)
APPIMAGE=$(find "$SCRIPT_DIR" -maxdepth 1 -name "*.AppImage" | head -1)

# â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
show_msg() {
  if command -v zenity &>/dev/null; then
    zenity --info --no-wrap --title="Groovy Installer" --text="$1" 2>/dev/null || true
  elif command -v kdialog &>/dev/null; then
    kdialog --title "Groovy Installer" --msgbox "$1" 2>/dev/null || true
  else
    echo -e "$1"
  fi
}

show_error() {
  if command -v zenity &>/dev/null; then
    zenity --error --no-wrap --title="Groovy Installer" --text="$1" 2>/dev/null || true
  elif command -v kdialog &>/dev/null; then
    kdialog --title "Groovy Installer" --error "$1" 2>/dev/null || true
  else
    echo -e "ERROR: $1" >&2
  fi
}

# â”€â”€ If .deb exists, install it natively â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
if [ -n "$DEB_FILE" ]; then
  echo "Encontrado paquete Debian: $DEB_FILE"
  if command -v xdg-open &>/dev/null; then
    xdg-open "$DEB_FILE" &
    show_msg "Abriendo el Instalador de Paquetes del sistema...\n\nPresiona 'Instalar' en la ventana que aparecerÃ¡."
    exit 0
  elif command -v pkexec &>/dev/null && command -v apt-get &>/dev/null; then
    pkexec apt-get install -y "$DEB_FILE"
    show_msg "âœ… Â¡Groovy se ha instalado correctamente!"
    exit 0
  fi
fi

# â”€â”€ Check AppImage exists â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
if [ -z "$APPIMAGE" ]; then
  show_error "No se encontrÃ³ ningÃºn instalador (.deb o .AppImage) en esta carpeta.\n\nDescarga Groovy-Linux.deb o Groovy-*-linux-x86_64.AppImage en la misma carpeta."
  exit 1
fi

APPIMAGE_NAME="$(basename "$APPIMAGE")"

# â”€â”€ Mark AppImage as executable â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
chmod +x "$APPIMAGE"

# â”€â”€ Ask where to install â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
INSTALL_DIR="$HOME/.local/bin"
ICONS_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
APPS_DIR="$HOME/.local/share/applications"

mkdir -p "$INSTALL_DIR" "$ICONS_DIR" "$APPS_DIR"

# Copy AppImage to ~/.local/bin/groovy
DEST="$INSTALL_DIR/Groovy.AppImage"
cp -f "$APPIMAGE" "$DEST"
chmod +x "$DEST"

# ── Create .desktop entry (enables app menu + dock icon) ───
ICON_PATH="$ICONS_DIR/com.groovy.music.png"

# Try to extract icon from AppImage or copy
if [ -f "$SCRIPT_DIR/com.groovy.music.png" ]; then
  cp "$SCRIPT_DIR/com.groovy.music.png" "$ICON_PATH"
  cp "$SCRIPT_DIR/com.groovy.music.png" "$ICONS_DIR/groovy.png"
elif [ -f "$SCRIPT_DIR/groovy.png" ]; then
  cp "$SCRIPT_DIR/groovy.png" "$ICON_PATH"
  cp "$SCRIPT_DIR/groovy.png" "$ICONS_DIR/groovy.png"
else
  # Extract from AppImage if possible
  "$DEST" --appimage-extract usr/share/icons/hicolor/256x256/apps/com.groovy.music.png &>/dev/null && \
    mv squashfs-root/usr/share/icons/hicolor/256x256/apps/com.groovy.music.png "$ICON_PATH" && \
    cp "$ICON_PATH" "$ICONS_DIR/groovy.png" && \
    rm -rf squashfs-root || true
fi

ICON_ARG="$ICON_PATH"
[ ! -f "$ICON_PATH" ] && ICON_ARG="application-x-executable"

cat > "$APPS_DIR/com.groovy.music.desktop" << EOF
[Desktop Entry]
Name=Groovy
Comment=Stream music from YouTube Music
Exec=$DEST
Icon=$ICON_ARG
Terminal=false
Type=Application
Categories=Audio;Music;Player;AudioVideo;
Keywords=music;streaming;youtube;
StartupWMClass=com.groovy.music
EOF

chmod +x "$APPS_DIR/com.groovy.music.desktop"
cp "$APPS_DIR/com.groovy.music.desktop" "$APPS_DIR/groovy.desktop"

# Refresh desktop database
if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "$APPS_DIR" &>/dev/null || true
fi
if command -v gtk-update-icon-cache &>/dev/null; then
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" &>/dev/null || true
fi

show_msg "âœ… Groovy was installed successfully!\n\nYou can now:\nâ€¢ Find it in your Applications menu (under Music)\nâ€¢ Launch it by double-clicking the AppImage directly\n\nInstalled to: $DEST"
