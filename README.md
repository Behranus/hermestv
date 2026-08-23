# 🔱 HermesTV

**Free & Open-Source IPTV Player** — Watch live TV channels, movies and series from around the world.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flatpak](https://img.shields.io/badge/Flatpak-Install-blue.svg)](https://flathub.org/apps/com.iptv.iptv_player)
[![Android](https://img.shields.io/badge/Android-APK-green.svg)](#android)
[![Linux](https://img.shields.io/badge/Linux-Tar.gz-orange.svg)](#linux)

---

## ✨ Features

- 📺 **Live TV** — 7,000+ free & legal world channels via iptv-org
- 🎬 **VOD** — Movies & TV series with poster art and IMDb ratings
- 📝 **Subtitles** — HLS embedded + external SRT/VTT/ASS + OpenSubtitles
- 🔊 **Multi-audio** — Language track selection
- 📋 **EPG** — Electronic Program Guide
- 🎮 **TV Remote** — D-pad / gamepad navigation support
- 🌍 **Multi-language** — Türkçe, English, Kurdî
- 🎨 **Dark Theme** — Zorin OS inspired design
- 🔒 **Secure** — Minimum permissions, no user data collection

## 📦 Install

### Flatpak (Linux)
```bash
# From Flathub (recommended)
flatpak install flathub com.iptv.iptv_player

# Or build from source
git clone https://github.com/Behranus/hermestv.git
cd hermestv
flatpak-builder --user --install --force-clean build-dir flatpak/com.iptv.iptv_player.yml
```

### Android APK
Download the latest APK from [Releases](https://github.com/Behranus/hermestv/releases) or build:
```bash
flutter build apk --release
```

### Linux (Tarball)
```bash
flutter build linux --release
tar czf hermestv-linux.tar.gz -C build/linux/x64/release/bundle .
tar xzf hermestv-linux.tar.gz
./hermestv
```

## 🏗️ Building from Source

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.24+
- Android SDK (for APK)
- Linux GTK development libraries (for Linux)

### Build
```bash
# Get dependencies
flutter pub get

# Build Android APK
flutter build apk --release

# Build Linux
flutter build linux --release

# Build Flatpak
flatpak-builder --user --install --force-clean build-dir flatpak/com.iptv.iptv_player.yml
```

## 📂 Project Structure

```
hermestv/
├── lib/
│   ├── l10n/              # Localization (TR/EN/KU)
│   ├── models/            # Data models
│   ├── screens/           # UI screens
│   ├── services/          # Business logic
│   ├── state/             # App state (Provider)
│   └── widgets/           # Reusable widgets
├── flatpak/               # Flatpak packaging
├── screenshots/           # App screenshots
├── android/               # Android platform
├── linux/                 # Linux platform
└── pubspec.yaml           # Dependencies
```

## 🔐 Permissions

HermesTV requests **minimum permissions**:

| Permission | Purpose |
|---|---|
| Network | Stream IPTV content |
| Display (Wayland/X11) | Show video |
| Audio (PulseAudio) | Play sound |
| GPU (DRI) | Hardware video decode |

**NOT requested:** Microphone, Camera, Location, Notifications, Home directory access.

## 🌍 Supported Languages

| Language | Code | Flag |
|---|---|---|
| Türkçe | `tr` | 🇹🇷 |
| English | `en` | 🇬🇧 |
| Kurdî | `ku` | 🏴󠁩󠁲󠀱󠀶󠁿 |

## 📜 License

MIT License — see [LICENSE](LICENSE) for details.

## 🤝 Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## ⚠️ Disclaimer

HermesTV is a media player. Users are responsible for the content they access. Only use legal and authorized IPTV sources.

---

**Made with ❤️ by Behranus**
