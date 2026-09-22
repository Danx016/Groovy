# Groovy - Modern Music Streaming Player & Web Client

**Groovy** is a modern, high-performance music streaming application and web client with an elegant Apple Music-inspired interface. Stream your music library, enjoy official high-definition album covers, experience animated motion artwork, and sync time-coded lyrics smoothly across Android, Windows, Web, macOS, Linux, and iOS.

[![Groovy](https://img.shields.io/badge/Groovy-v1.3.4-fa243c?style=for-the-badge&logo=github)](https://github.com/Danx016/Groovy)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platforms-Android%20%7C%20Windows%20%7C%20Web%20%7C%20macOS%20%7C%20Linux%20%7C%20iOS-informational?style=for-the-badge)](https://github.com/Danx016/Groovy/releases)

---

## ✨ Features

- 🎨 **Apple Music UI & Aesthetics** — Sleek dark glassmorphism interface, custom Cupertino navigation, and modern typography inspired by Apple Music.
- 🎬 **Apple Music Motion Artwork** — Official hardware-accelerated looping video covers (HLS `.m3u8` in 1:1 format) with seamless fallback to high-resolution artwork and organic breathing animations.
- 🖼️ **Original Studio HD Covers** — Automatically resolves genuine 1400×1400 studio album covers via the Apple Music storefront, replacing low-resolution video thumbnails.
- 🎵 **Ultra-Fast & Lossless Streaming** — Stream music instantly with zero latency, gapless playback, and native audio decoding powered by `libmpv` and `just_audio`.
- 🎤 **Fluid Time-Synced Lyrics** — Apple Music-style fluid scrolling lyrics with syllable highlighting and sub-second synchronization powered by LRCLIB.
- 🔗 **Groovy Connect** — Multi-device live sync and remote control across Desktop, Mobile, and Web.
- 🔍 **Intelligent Dual Search** — High-speed search querying official tracks, albums, and artists with smart query sanitization and deduplication.
- 🚗 **Android Auto & System Integration** — Full Android Auto support, Windows Taskbar thumbnail controls, media keys, and Discord Rich Presence.
- 🔄 **Built-In Automatic Updates** — Direct update notifications and in-app installer downloads for Windows and Android.
- 📦 **Smart Cache & Offline Mode** — 2-tier memory and persistent disk caching for instantaneous loading and offline listening.

---

## 📱 Supported Platforms

| Platform | Support | Packaging |
| :--- | :---: | :--- |
| **Android** | ✅ | Universal APK & Play Store AAB |
| **Windows** | ✅ | Native x64 Installer (`.exe`) & Portable |
| **Web** | ✅ | Responsive React SPA Client |
| **macOS** | ✅ | Universal DMG & App Bundle |
| **Linux** | ✅ | Native AppImage & Tarball |
| **iOS** | ✅ | Native IPA |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.0.0 or higher)
- [Node.js](https://nodejs.org/) (for Web client & Backend API)

### Flutter Client

```bash
# Clone repository
git clone https://github.com/Danx016/Groovy.git
cd Groovy

# Install Flutter dependencies
flutter pub get

# Run on your active device (Windows, Android, macOS, Linux)
flutter run

# Build Android Release APK
flutter build apk --release

# Build Windows Release Installer
flutter build windows --release
```

### Web App (React)

```bash
cd react-website
npm install
npm run dev
```

### Cloud Backend (API)

```bash
cd groovy-backend
npm install
npm run dev
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

- **Developer:** Danilo Rodelo ([@Danx016](https://github.com/Danx016))
- **Repository:** [https://github.com/Danx016/Groovy](https://github.com/Danx016/Groovy)
