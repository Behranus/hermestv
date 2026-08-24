# Snap Store Gönderim Rehberi

## Adım 1: Snapcraft CLI Kur

```bash
sudo snap install snapcraft --classic
```

## Adım 2: Snap Store Hesabı Oluştur

1. https://snapcraft.io/account adresine git
2. GitHub ile giriş yap
3. Username seç (örn: `hermestv`)

## Adım 3: Build Et

```bash
cd ~/Masaüstü/orhan
snapcraft
```

Bu `hermestv_2.1.0_amd64.snap` dosyasını oluşturur.

## Adım 4: Yükle

```bash
# Login ol
snapcraft login --with ~/.snap/snapcraft.cfg

# Push et
snapcraft upload hermestv_2.1.0_amd64.snap

# Release et
snapcraft release hermestv stable
```

## Adım 5: İnceleme

Snap Store ekibi inceleme yapacak. Gerekenler:
- ✅ `snapcraft.yaml` doğru
- ✅ Icon mevcut
- ✅ License (MIT) tanımlı
- ✅ Desktop entry var
- ✅ AppStream metadata var

## Adım 6: Onay Sonrası

Onaylandığında:
- `sudo snap install hermestv` ile kurulabilecek
- Snap Store'da görünecek
- GNOME Software'da Snap sekmesinde aranabilecek

## Gerekli Dosyalar

```
snap/snapcraft.yaml    # Snap build config
flatpak/com.iptv.iptv_player.metainfo.xml  # AppStream metadata
flatpak/com.iptv.iptv_player.desktop       # Desktop entry
flatpak/com.iptv.iptv_player.png           # Icon
LICENSE                                   # MIT license
```

## Linkler

- **Snap Store:** https://snapcraft.io/hermestv (onay sonrası)
- **GitHub:** https://github.com/Behranus/hermestv
