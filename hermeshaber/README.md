# HermesHaber

Dünya basınından haberleri Türkçeye çevirip tek akışta sunan uygulama: web (PWA) + Android (Flutter).

- **worker/** — Cloudflare Worker: RSS toplayıcı, Türkçe çeviri, makale okuyucu ve radyo dizini API'si (`/api/feed`, `/api/read`, `/api/radio`).
- **worker/data.js** — 136 güvenilir kaynak (14 bölge, 9 kategori), öne çıkan radyo istasyonları ve 69 ülke listesi.
- **public/** — web arayüzü: bölge/kategori sekmeleri, okuyucu, mini radyo oynatıcısı.
- **app/** — Flutter Android uygulaması (aynı API'yi kullanır, `just_audio` ile radyo).

## Bölgeler

Tümü · Avrupa · ABD · Kanada · Latin Amerika · Afrika · Orta Doğu · Türkiye · Çin · Rusya · Güney Asya · Doğu Asya · Güneydoğu Asya · Okyanusya

## Kategoriler

Gündem · Siyaset · Ekonomi · Teknoloji · Bilim · Sağlık · İklim · Spor · Kültür

## Radyo

`/api/radio?kind=featured` öne çıkan kamu yayıncılarını, `?kind=country&country=TR` ise
[radio-browser.info](https://www.radio-browser.info) dizininden o ülkenin HTTPS yayınlarını döndürür.

## Çalıştırma

```bash
# web + worker (Sites / wrangler)
wrangler dev --config deploy.json

# Android
cd app && flutter pub get && flutter build apk --release
```

Uygulama API adresi `HERMES_API_URL` derleme değişkeniyle verilir.
