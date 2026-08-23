# 🔱 HermesTV — Flathub & Linux Mağaza Gönderim Rehberi

## 📋 Hazırlık Kontrol Listesi

- [x] GitHub repo: `github.com/Behranus/hermestv`
- [x] LICENSE dosyası (MIT)
- [x] README.md
- [x] Flatpak manifest: `flatpak/com.iptv.iptv_player.yml`
- [x] Desktop dosyası: `flatpak/com.iptv.iptv_player.desktop`
- [x] Metainfo XML: `flatpak/com.iptv.iptv_player.metainfo.xml`
- [x] Screenshot'lar: `screenshots/`
- [x] Uygulama ikonu: `flatpak/com.iptv.iptv_player.png`
- [x] `appstreamcli validate` — 0 hata

---

## 🏪 1. Flathub'a Gönderim

### Adım 1: GitHub'da Repo Oluştur
```bash
# GitHub'da yeni repo oluştur: Behranus/hermestv
git remote add origin https://github.com/Behranus/hermestv.git
git push -u origin surum-17f3e4e
```

### Adım 2: Flathub Flatpak Repo'su Forkla
1. https://github.com/flathub/com.iptv.iptv_player adresine git
2. "Fork" butonuna bas
3. Forklanan repo'da `com.iptv.iptv_player.yml` manifest'ini düzenle:

```yaml
app-id: com.iptv.iptv_player
runtime: org.freedesktop.Platform
runtime-version: '24.08'
sdk: org.freedesktop.Sdk
command: hermestv

finish-args:
  - --share=network
  - --socket=wayland
  - --socket=x11
  - --share=ipc
  - --socket=pulseaudio
  - --device=dri
  - --filesystem=xdg-run/wayland-0

modules:
  - name: hermestv
    buildsystem: simple
    build-commands:
      - mkdir -p /app/bin /app/lib /app/data
      - cp bundle/hermestv /app/hermestv
      - cp -r bundle/lib/* /app/lib/
      - cp -r bundle/data/* /app/data/
      - |
        cat > /app/bin/hermestv << 'ENDOFSCRIPT'
        #!/bin/sh
        export LD_LIBRARY_PATH="/app/lib:$LD_LIBRARY_PATH"
        if [ -n "$WAYLAND_DISPLAY" ]; then
          export GDK_BACKEND=wayland
        fi
        exec /app/hermestv "$@"
        ENDOFSCRIPT
      - chmod +x /app/bin/hermestv
    sources:
      - type: git
        url: https://github.com/Behranus/hermestv.git
        tag: v2.1.0
```

### Adım 3: PR Oluştur
1. Forklanan repo'da değişiklikleri commit et
2. https://github.com/flathub/com.iptv.iptv_player adresine PR aç
3. PR açıklamasına şunları ekle:
   - Uygulama açıklaması
   - Screenshots linkleri
   - Lisans bilgisi

### Adım 4: Flathub Ekibinden Onay Bekle
- Flathub ekibi PR'ı inceleyecek
- Gerekli düzeltmeleri isteyebilir
- Onaylandıktan sonra otomatik build edilecek

---

## 🏬 2. Bazaar (GNOME Software) Gönderim

Bazaar, Flathub tabanlıdır. Flathub'a gönderildikten sonra otomatik olarak görünür.

### Ek Adım: AppStream Metadata
Metainfo XML zaten hazır. Flathub'a gönderildikten sonra Bazaar'da da görünecek.

---

## 📱 3. Diğer Linux Mağazaları

### Snap Store
```bash
# snapcraft.yaml oluştur
snapcraft.ini için:
name: hermestv
version: '2.1.0'
summary: Free & Open-Source IPTV Player
description: |
  HermesTV lets you watch free live TV channels, movies and series.
grade: stable
confinement: strict
base: core22

parts:
  hermestv:
    plugin: flutter
    source: .
    flutter-target: lib/main.dart

apps:
  hermestv:
    command: hermestv
    extensions: [flutter]
    plugs:
      - network
      - audio-playback
      - opengl
```

```bash
snapcraft
snapcraft upload hermestv_2.1.0_amd64.snap
```

### AUR (Arch Linux)
```bash
# PKGBUILD dosyası
# AUR'da paket oluşturmak için:
# https://wiki.archlinux.org/title/Creating_packages
```

### Flatpak-builder ile Yerel Build
```bash
cd ~/Masaüstü/orhan
flatpak-builder --user --install --force-clean build-dir flatpak/com.iptv.iptv_player.yml
```

---

## 🌐 4. Ücretsiz Sunucu (GitHub Pages)

### Adım 1: GitHub Pages Aktifleştir
1. Repo ayarları → Pages
2. Source: "Deploy from a branch"
3. Branch: `main`, Folder: `/docs`
4. Kaydet

### Adım 2: Dosyaları Yükle
```bash
# docs/ klasörünü commit et
git add docs/
git commit -m "GitHub Pages download sayfası"
git push
```

### Adım 3: Erişim
- **URL:** `https://behranus.github.io/hermestv/`
- **APK indirme:** `https://behranus.github.io/hermestv/hermestv.apk`
- **Linux indirme:** `https://behranus.github.io/hermestv/hermestv-linux-x64.tar.gz`

### Adım 4: APK Yükle
```bash
# docs/ klasörüne APK ve Linux dosyalarını kopyala
cp /home/berjin/apk-share/hermestv.apk docs/
cp /home/berjin/apk-share/hermestv-linux-x64.tar.gz docs/
cp screenshots/*.png docs/
git add docs/
git commit -m "APK ve Linux dosyalarını GitHub Pages'e ekle"
git push
```

---

## 🔄 5. Otomatik Build (CI/CD)

### GitHub Actions ile Otomatik APK Build
`.github/workflows/build.yml`:
```yaml
name: Build
on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.x'
      - run: flutter pub get
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v4
        with:
          name: hermestv-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

---

## ✅ Özet

| Mağaza | Durum | Gereken |
|---|---|---|
| **Flathub** | Hazır PR bekliyor | GitHub repo + PR |
| **Bazaar** | Otomatik (Flathub sonrası) | — |
| **Snap Store** | Hazırlanabilir | snapcraft.yaml |
| **GitHub Pages** | ✅ Ücretsiz hosting | docs/ klasörü |
| **AUR** | Hazırlanabilir | PKGBUILD |

---

**Sonraki adım:** GitHub'da repo oluştur ve Flathub'a PR gönder! 🚀
