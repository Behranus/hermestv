# Flathub Gönderim Rehberi

## Adım 1: Flathub Depo Oluştur

GitHub'da yeni repo oluştur:
- **URL:** https://github.com/new
- **Repository name:** `com.iptv.iptv_player`
- **Description:** `HermesTV — Free IPTV Player for Linux`
- **Public** seç
- **Create repository**

## Adım 2: Dosyaları Yükle

Repo'ya şu dosyaları yükle:
- `com.iptv.iptv_player.yml` (Flathub manifest)
- `com.iptv.iptv_player.metainfo.xml` (AppStream metadata)
- `com.iptv.iptv_player.desktop` (Desktop entry)
- `com.iptv.iptv_player.png` (Icon)

## Adım 3: Flathub'a PR Gönder

1. https://github.com/flathub/new adresine git
2. Repository name: `com.iptv.iptv_player`
3. Create repository
4. Fork'unuzdan Flathub repo'suna PR aç
5. PR'da şu bilgileri ekle:
   ```
   App ID: com.iptv.iptv_player
   Name: HermesTV
   Summary: Free IPTV Player for Linux
   Homepage: https://github.com/Behranus/hermestv
   ```

## Adım 4: Flathub Review

Flathub ekibi PR'ı inceleyecek. Muhtemelen isteyecekleri:
- ✅ AppStream metadata geçerli
- ✅ LICENSE dosyası var (MIT)
- ✅ Screenshot'lar var
- ✅ Build-from-source manifest doğru

## Adım 5: Onay Sonrası

Onaylandığında:
- Flathub'da otomatik publish edilecek
- `flatpak install flathub com.iptv.iptv_player` ile kurulabilecek
- GNOME Software'da arama kısmında görünecek

## Gerekli Dosyalar

```
com.iptv.iptv_player.yml        # Build-from-source manifest
com.iptv.iptv_player.metainfo.xml  # AppStream metadata
com.iptv.iptv_player.desktop      # Desktop entry
com.iptv.iptv_player.png          # Icon
LICENSE                           # MIT license
```

## Test

Yerel test:
```bash
flatpak-builder --user --install --force-clean build-dir flatpak/com.iptv.iptv_player.yml
flatpak run com.iptv.iptv_player
```

## Linkler

- **Flathub:** https://flathub.org/apps/com.iptv.iptv_player (onay sonrası)
- **GitHub Repo:** https://github.com/Behranus/hermestv
- **GitHub Pages:** https://behranus.github.io/hermestv/
