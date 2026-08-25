#!/bin/sh
# ============================================================
# AI Altyazi Ceviri Plugin - Kurulum Scripti
# Zgemma H9 Twin SE / OpenATV icin
# ============================================================

PLUGIN_DIR="/usr/lib/enigma2/python/Plugins/Extensions/SubtitleTranslate"
BACKUP_DIR="/tmp/subtitle_translate_backup"

echo "============================================"
echo "  AI Altyazi Ceviri Plugin - Kurulum"
echo "============================================"
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "[HATA] Bu scripti root olarak calistirin!"
    echo "Kullanim: su -c '/path/to/install.sh'"
    exit 1
fi

# Check if Enigma2 is installed
if [ ! -d "/usr/lib/enigma2/python/Plugins" ]; then
    echo "[HATA] Enigma2 bulunamadi!"
    echo "Bu plugin sadece Enigma2 tabanli uydu alicilarinda calisir."
    exit 1
fi

echo "[1/5] Mevcut plugin yedekleniyor..."
mkdir -p "$BACKUP_DIR"
if [ -d "$PLUGIN_DIR" ]; then
    cp -r "$PLUGIN_DIR" "$BACKUP_DIR/" 2>/dev/null
    echo "      Eski plugin yedeklendi: $BACKUP_DIR/SubtitleTranslate"
fi

echo "[2/5] Plugin dosyalari kopyalaniyor..."
mkdir -p "$PLUGIN_DIR"

# Copy all plugin files
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for f in __init__.py plugin.py translation_engines.py subtitle_manager.py subtitle_overlay.py utils.py; do
    if [ -f "$SCRIPT_DIR/$f" ]; then
        cp "$SCRIPT_DIR/$f" "$PLUGIN_DIR/$f"
        echo "      $f kopyalandi"
    else
        echo "      [UYARI] $f bulunamadi!"
    fi
done

# Set permissions
chmod -R 755 "$PLUGIN_DIR"
chown -R root:root "$PLUGIN_DIR"

echo "[3/5] Gerekli kutuphaneler kontrol ediliyor..."

# Check Python version
PYTHON_VER=$(python3 -c "import sys; print(sys.version_info.major)" 2>/dev/null || echo "2")
echo "      Python versiyonu: $PYTHON_VER"

# Check if requests is available (optional)
python3 -c "import urllib.request" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "      urllib mevcut - OK"
else
    echo "      [UYARI] urllib bulunamadi"
fi

echo "[4/5] Plugin basariyla kuruldu!"
echo "      Konum: $PLUGIN_DIR"
echo ""

echo "[5/5] Onemli bilgiler:"
echo "============================================"
echo "  - Enigma2'yi yeniden baslatin (GUI restart)"
echo "  - Plugin menusunden 'AI AltYazi Ceviri' acin"
echo "  - Ayarlari yapin ve ceviriyi aktif edin"
echo ""
echo "  Ucretsiz motor: Google Translate (API key gerekmez)"
echo "  Ucretli motorlar: DeepL, Groq Whisper"
echo ""
echo "  DeepL API: https://www.deepl.com/pro-api"
echo "  Groq API: https://console.groq.com"
echo "============================================"

# Ask for restart
echo ""
read -p "Enigma2'yi simdi yeniden baslatmak ister misiniz? (e/h): " RESTART
if [ "$RESTART" = "e" ] || [ "$RESTART" = "E" ]; then
    echo "Enigma2 yeniden baslatiliyor..."
    killall -9 enigma2
fi

echo ""
echo "Kurulum tamamlandi! Iyi seyirler."
