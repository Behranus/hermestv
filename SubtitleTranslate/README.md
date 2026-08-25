# AI Altyazı Çeviri Plugin - Enigma2 / OpenATV

## 📡 Zgemma H9 Twin SE Uyumlu

**Uydu yayınlarındaki altyazıları yapay zeka ile Türkçeye çevirin!**

---

## 🎯 Özellikler

- **Ücretsiz Çeviri**: Google Translate entegrasyonu (API key gerektirmez)
- **DeepL Entegrasyonu**: Yüksek kaliteli çeviri (API key gerektirir)
- **Groq Whisper**: Ses tanıma + çeviri (API key gerektirir)
- **Otomatik Dil Algılama**: 30+ dil desteği
- **Gerçek Zamanlı**: Canlı yayın altyazılarını anında çevirir
- **DVB & Teletext**: Her iki altyazı formatını destekler
- **Özelleştirilebilir**: Yazı boyutu, renk, pozisyon, gecikme
- **Otomatik Başlatma**: OpenATV ile birlikte otomatik aktif olur

---

## 📋 Gereksinimler

- Zgemma H9 Twin SE (veya uyumlu Enigma2 cihazı)
- OpenATV image (Python 3 destekli)
- İnternet bağlantısı
- **Ücretsiz motor için**: Hiçbir şey gerekmez
- **DeepL için**: [DeepL API Key](https://www.deepl.com/pro-api)
- **Groq Whisper için**: [Groq API Key](https://console.groq.com)

---

## 🚀 Kurulum

### Yöntem 1: SCP ile (Önerilen)

```bash
# 1. Cihazınızın IP adresini bulun (Ayarlar > Ağ > Ağ Yapılandırma)
# 2. Bilgisayarınızdan terminal açın

# Plugin dosyalarını cihaza kopyalayın
scp -r SubtitleTranslate/ root@192.168.1.XXX:/usr/lib/enigma2/python/Plugins/Extensions/

# 3. Cihaza SSH ile bağlanın
ssh root@192.168.1.XXX

# 4. Kurulum scriptini çalıştırın
chmod +x /usr/lib/enigma2/python/Plugins/Extensions/SubtitleTranslate/install.sh
su -c '/usr/lib/enigma2/python/Plugins/Extensions/SubtitleTranslate/install.sh'

# 5. Enigma2'yi yeniden başlatın
killall -9 enigma2
```

### Yöntem 2: WebArayüz (OpenATV)

1. Tarayıcınızdan `http://192.168.1.XXX` adresine gidin
2. "Araçlar" > "Eklenti Yöneticisi" bölümüne gidin
3. ZIP dosyasını yükleyin (aşağıdaki bölümü oluşturun)

### Yöntem 3: Plugin ZIP Oluşturma

```bash
# Plugin dizinindeyken
cd SubtitleTranslate
zip -r /tmp/enigma2-ai-subtitle-translate.zip .
# Sonra web arayüzünden bu ZIP'i yükleyin
```

---

## ⚙️ Ayarlar

Plugin kurulduktan sonra:

1. **Menü** > **Eklentiler** > **AI Altyazı Çeviri**'ye gidin
2. Ayarları yapılandırın:

### Çeviri Motoru Seçenekleri

| Motor | API Key | Ücretsiz? | Kalite | Hız |
|-------|---------|-----------|--------|-----|
| Google Translate | Gerekmez | ✅ Evet | İyi | Hızlı |
| DeepL | Gerekir | ❌ Ücretli | Çok İyi | Orta |
| Groq Whisper | Gerekir | ❌ Ücretli | Çok İyi | Orta |

### Dil Ayarları

- **Kaynak Dil**: Otomatik Algıla (önerilen) veya belirli bir dil seçin
- **Hedef Dil**: Türkçe (varsayılan) veya başka bir dil

### Görünüm Ayarları

- **Yazı Boyutu**: Küçük / Orta / Büyük
- **Pozisyon**: Alt / Üst / Orta
- **Maks Satır**: 1-5 arası
- **Gecikme**: Milisaniye cinsinden (-5000 ile +5000 arası)

---

## 🔧 Kullanım

### Normal Kullanım

1. TV izlerken alt yazıları açın
2. Plugin otomatik olarak çeviri yapar
3. Çevrilmiş altyazı ekranda gösterilir

### Hızlı Erişim Menüsü

Plugin menüsünden (veya kısayol tuşu ile) hızlı kontrol menüsüne erişebilirsiniz:

- **[1]**: Çeviriyi aç/kapat
- **[2]**: Çeviri motorunu değiştir
- **[OK]**: Aç/kapat
- **[CANCEL]**: Kapat

---

## 🛠️ Sorun Giderme

### Plugin görünmüyor

```bash
# Enigma2'yi yeniden başlatın
killall -9 enigma2

# Plugin dosyalarının doğru yerde olduğunu kontrol edin
ls -la /usr/lib/enigma2/python/Plugins/Extensions/SubtitleTranslate/
```

### Çeviri yapmıyor

1. İnternet bağlantınızı kontrol edin
2. Plugin ayarlarında çevirinin aktif olduğunu doğrulayın
3. Hangi motoru kullandığınızı kontrol edin (API key gerekli mi?)
4. Kaynak dil seçiminin doğru olduğundan emin olun

### Hata alıyorum

```bash
# Log dosyasını kontrol edin
cat /tmp/enigma2.log | grep SubtitleTranslate

# Google Translate test edin
python3 -c "
import urllib.request, json
url = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=tr&dt=t&q=hello'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
resp = urllib.request.urlopen(req, timeout=10)
print(json.loads(resp.read().decode('utf-8'))[0][0][0])
"
```

### İnternet hızım yavaş

Ayarlar menüsünde "Google Translate" motorunu seçin - bu en hızlı ve ücretsiz seçenektir. DeepL biraz daha yavaş olabilir.

---

## 📁 Dosya Yapısı

```
SubtitleTranslate/
├── __init__.py              # Plugin kaydı (Enigma2 için)
├── plugin.py                # Ana ayarlar ekranı
├── translation_engines.py   # Çeviri motorları (Google, DeepL, Groq)
├── subtitle_manager.py      # Altyazı yakalama ve yönetimi
├── subtitle_overlay.py      # Altyazı gösterim ekranı
├── utils.py                 # Yardımcı fonksiyonlar
├── install.sh               # Kurulum scripti
└── README.md                # Bu dosya
```

---

## 🧩 Teknik Detaylar

### Çeviri Motoru Mimarisi

Plugin modüler bir çeviri motoru mimarisi kullanır:

```
DVB Altyazı → Yakalama → Çeviri Motoru → Overlay Ekranı → Kullanıcı
     ↓              ↓            ↓
  Teletext     DVBSubtitle   Google/DeepL/Groq
  Extraction   Extractor
```

### Enigma2 Entegrasyonu

- `eDVBSubtitleControl` ile altyazı olaylarını yakalar
- `eTimer` ile periyodik kontrol yapar
- `PluginDescriptor.WHERE_AUTOSTART` ile otomatik başlatma
- `config.plugins.SubtitleTranslate` ile ayar yönetimi

### Zgemma H9 Twin SE Uyumluluğu

- Hi3798MV200 SoC (ARM Cortex-A53)
- Python 3.x desteği
- OpenATV 7.x uyumlu
- 1280x720 UI çözünürlüğü

---

## 📝 Lisans

Bu plugin açık kaynaklıdır. İstediğiniz gibi değiştirip kullanabilirsiniz.

---

## 🤝 Katkı

Hatalar bulursanız veya geliştirmek isterseniz, katkılarınız hoş geldiniz!

---

## ⚡ Performans İpuçları

1. **Google Translate** en hızlı ve ücretsiz seçenektir
2. İnternet bağlantınız yavaşsa **Google Translate** kullanın
3. **Groq Whisper** sadece ses tanıma gerektiğinde kullanın
4. Altyazı gecikmesini ayarlayarak senkronizasyonu iyileştirin
5. "Yayındaki Altyazıyı Gizle" seçeneği ile çift altyazı sorununu önleyin

---

**Iyi seyirler! 🎬**
