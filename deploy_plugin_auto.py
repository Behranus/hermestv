#!/usr/bin/env python3
"""
Auto-deploy SubtitleTranslate plugin to Zgemma H9 Twin SE via SSH
Non-interactive version for automated deployment
"""
import paramiko
import os
import sys

DEVICE_IP = "192.168.1.4"
DEVICE_USER = "root"
DEVICE_PASS = "0000"
DEVICE_PORT = 22
REMOTE_BASE = "/usr/lib/enigma2/python/Plugins/Extensions/SubtitleTranslate"
PLUGIN_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "SubtitleTranslate")

def main():
    print("="*50)
    print("  AI AltYazi Ceviri Plugin - Otomatik Kurulum")
    print(f"  Hedef: {DEVICE_IP}")
    print("="*50)

    # Connect
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    print("\n[1/6] Cihaza baglaniliyor...")
    try:
        client.connect(
            hostname=DEVICE_IP,
            port=DEVICE_PORT,
            username=DEVICE_USER,
            password=DEVICE_PASS,
            timeout=15,
            allow_agent=False,
            look_for_keys=False
        )
        print("      ✓ Baglanti basarili!")
    except Exception as e:
        print(f"      ✗ Baglanti hatasi: {e}")
        sys.exit(1)

    # Check device
    print("\n[2/6] Cihaz bilgisi...")
    stdin, stdout, stderr = client.exec_command("cat /proc/stb/info/chipset 2>/dev/null || echo 'Bilinmiyor'")
    chipset = stdout.read().decode().strip()
    print(f"      Chipset: {chipset}")

    stdin, stdout, stderr = client.exec_command("cat /etc/image-version 2>/dev/null | head -3 || echo 'Version bilinmiyor'")
    version = stdout.read().decode().strip()
    print(f"      Image: {version}")

    # Create remote dir
    print("\n[3/6] Uzak dizin olusturuluyor...")
    stdin, stdout, stderr = client.exec_command(f"mkdir -p {REMOTE_BASE}")
    stderr.read()
    print(f"      ✓ {REMOTE_BASE}")

    # Upload files
    print("\n[4/6] Dosyalar yukleniyor...")
    sftp = client.open_sftp()

    files = [
        "__init__.py", "plugin.py", "translation_engines.py",
        "subtitle_manager.py", "subtitle_overlay.py", "utils.py",
        "install.sh", "README.md"
    ]

    uploaded = 0
    for f in files:
        local_path = os.path.join(PLUGIN_DIR, f)
        remote_path = f"{REMOTE_BASE}/{f}"
        if os.path.exists(local_path):
            try:
                sftp.put(local_path, remote_path)
                print(f"      ✓ {f}")
                uploaded += 1
            except Exception as e:
                print(f"      ✗ {f}: {e}")
        else:
            print(f"      ✗ {f} bulunamadi!")
    sftp.close()

    if uploaded == 0:
        print("\n      Hiç dosya yuklenemedi!")
        client.close()
        sys.exit(1)

    # Set permissions
    print(f"\n[5/6] Izinler ayarlaniyor... ({uploaded} dosya)")
    client.exec_command(f"chmod -R 755 {REMOTE_BASE}")
    client.exec_command(f"chown -R root:root {REMOTE_BASE}")
    print("      ✓ Tamamlandi")

    # Restart Enigma2
    print("\n[6/6] Enigma2 yeniden baslatiliyor...")
    stdin, stdout, stderr = client.exec_command("killall -9 enigma2 2>/dev/null; echo done")
    stdout.read()
    print("      ✓ Enigma2 yeniden baslatildi!")

    # Summary
    print("\n" + "="*50)
    print("  KURULUM BASARILI!")
    print("="*50)
    print(f"""
  Plugin kuruldu: {REMOTE_BASE}
  Yuklenen dosya: {uploaded}/{len(files)}
  
  sirasiyla:
    1. TV'nizde 30-60 saniye bekleyin
    2. Menu > Eklentiler > AI AltYazi Ceviri
    3. Ayarlari yapin (motor, dil secin)
    4. Ceviriyi aktif edin
  
  Ucretsiz motor: Google Translate (API key gerektirmez)
  API key gerekli: DeepL, Groq Whisper
    - DeepL: https://www.deepl.com/pro-api
    - Groq:  https://console.groq.com
""")

    client.close()
    print("  Iyi seyirler! 🎬")

if __name__ == "__main__":
    main()
