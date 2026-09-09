#!/usr/bin/env bash
# ============================================================
# build_linux_appimage.sh
# Builds the Groovy Flutter Linux app and packages it as an
# AppImage — a portable, single-file executable that any
# modern Linux distro can run without installation.
#
# Requirements (Ubuntu/Debian):
#   sudo apt-get install -y clang cmake ninja-build pkg-config \
#     libgtk-3-dev liblzma-dev libstdc++-12-dev libasound2-dev \
#     libnotify-dev libsecret-1-dev libjsoncpp-dev libmpv-dev mpv
#
# Usage:
#   ./build_linux_appimage.sh            # uses version from pubspec.yaml
#   ./build_linux_appimage.sh 1.0.90     # override version
# ============================================================

set -euo pipefail

APP_NAME="Groovy"
EXEC_NAME="groovy"
VERSION="${1:-$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)}"
BUNDLE_DIR="build/linux/x64/release/bundle"
APPDIR="build/linux/AppDir"
OUTPUT="Groovy-${VERSION}-linux-x86_64.AppImage"

echo "🎵 Building ${APP_NAME} ${VERSION} AppImage..."

# ── 1. Flutter build ────────────────────────────────────────
echo "⚙️  Running flutter build linux..."
flutter build linux --release

# ── 2. Download yt-dlp binary ───────────────────────────────
echo "📥 Downloading yt-dlp..."
if [ ! -f "${BUNDLE_DIR}/yt-dlp" ]; then
  curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
    -o "${BUNDLE_DIR}/yt-dlp"
  chmod a+rx "${BUNDLE_DIR}/yt-dlp"
else
  echo "   yt-dlp already present, skipping."
fi

# ── 3. Create AppDir structure ───────────────────────────────
echo "📁 Creating AppDir..."
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}/usr/bin"
mkdir -p "${APPDIR}/usr/lib/${EXEC_NAME}"
mkdir -p "${APPDIR}/usr/share/applications"
mkdir -p "${APPDIR}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${APPDIR}/usr/share/icons/hicolor/512x512/apps"

# Copy bundle into AppDir
cp -r "${BUNDLE_DIR}/." "${APPDIR}/usr/lib/${EXEC_NAME}/"

# Launcher wrapper script (sets up runtime library paths)
cat > "${APPDIR}/usr/bin/${EXEC_NAME}" << 'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
APPLIB="${HERE}/../lib/groovy"
export LD_LIBRARY_PATH="${APPLIB}/lib:${LD_LIBRARY_PATH:-}"
exec "${APPLIB}/groovy" "$@"
EOF
chmod +x "${APPDIR}/usr/bin/${EXEC_NAME}"

# Desktop entry
cat > "${APPDIR}/usr/share/applications/${EXEC_NAME}.desktop" << EOF
[Desktop Entry]
Name=${APP_NAME}
Comment=Stream music from YouTube Music
Exec=${EXEC_NAME}
Icon=${EXEC_NAME}
Terminal=false
Type=Application
Categories=Audio;Music;Player;AudioVideo;
Keywords=music;streaming;youtube;
StartupWMClass=groovy
EOF

# Copy icons
if [ -f "assets/app_icon.png" ]; then
  cp assets/app_icon.png "${APPDIR}/usr/share/icons/hicolor/256x256/apps/${EXEC_NAME}.png"
fi
if [ -f "assets/app_icon_1024.png" ]; then
  cp assets/app_icon_1024.png "${APPDIR}/usr/share/icons/hicolor/512x512/apps/${EXEC_NAME}.png"
fi

# AppDir root symlinks required by AppImage spec
cp "${APPDIR}/usr/share/applications/${EXEC_NAME}.desktop" "${APPDIR}/${EXEC_NAME}.desktop"
cp "${APPDIR}/usr/share/icons/hicolor/256x256/apps/${EXEC_NAME}.png" "${APPDIR}/${EXEC_NAME}.png"
ln -sf "${EXEC_NAME}.png" "${APPDIR}/.DirIcon"

# AppRun entrypoint (required)
cat > "${APPDIR}/AppRun" << 'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
APPLIB="${HERE}/usr/lib/groovy"
export LD_LIBRARY_PATH="${APPLIB}/lib:${LD_LIBRARY_PATH:-}"
export XDG_DATA_DIRS="${HERE}/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "${APPLIB}/groovy" "$@"
EOF
chmod +x "${APPDIR}/AppRun"

# ── 4. Download appimagetool ─────────────────────────────────
echo "📥 Fetching appimagetool..."
TOOL="build/linux/appimagetool-x86_64.AppImage"
if [ ! -f "${TOOL}" ]; then
  curl -L \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" \
    -o "${TOOL}"
  chmod +x "${TOOL}"
fi

# ── 5. Package AppImage ──────────────────────────────────────
echo "📦 Packaging AppImage..."
ARCH=x86_64 "${TOOL}" --no-appstream "${APPDIR}" "${OUTPUT}"

echo ""
echo "✅ Done! AppImage created:"
echo "   ${OUTPUT}"
echo ""
echo "Usage on target machine:"
echo "   chmod +x ${OUTPUT}"
echo "   ./${OUTPUT}"
