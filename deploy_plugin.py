#!/usr/bin/env python3
"""
Deploy SubtitleTranslate plugin to Zgemma H9 Twin SE via SSH/SCP
"""
import paramiko
import os
import sys
import time

# Configuration
DEVICE_IP = "192.168.1.4"
DEVICE_USER = "root"
DEVICE_PASS = "0000"
DEVICE_PORT = 22
REMOTE_BASE = "/usr/lib/enigma2/python/Plugins/Extensions/SubtitleTranslate"
PLUGIN_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "SubtitleTranslate")

def create_ssh_client():
    """Create and connect SSH client."""
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    print(f"[1/5] {DEVICE_IP} adresine baglaniliyor...")
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
        return client
    except paramiko.AuthenticationException:
        print("      ✗ Sifre hatali!")
        sys.exit(1)
    except Exception as e:
        print(f"      ✗ Baglanti hatasi: {e}")
        sys.exit(1)

def check_device(client):
    """Check device information."""
    print("\n[2/5] Cihaz bilgisi kontrol ediliyor...")
    
    # Check chipset
    stdin, stdout, stderr = client.exec_command("cat /proc/stb/info/chipset 2>/dev/null || echo 'Bilinmiyor'")
    chipset = stdout.read().decode().strip()
    print(f"      Chipset: {chipset}")
    
    # Check Python version
    stdin, stdout, stderr = client.exec_command("python3 --version 2>/dev/null || python --version 2>/dev/null || echo 'Python bulunamadi'")
    python_ver = stdout.read().decode().strip()
    print(f"      Python: {python_ver}")
    
    # Check if Enigma2 exists
    stdin, stdout, stderr = client.exec_command("ls /usr/lib/enigma2/python/Plugins/Extensions/ 2>/dev/null | head -5 || echo 'Enigma2 bulunamadi'")
    extensions = stdout.read().decode().strip()
    if extensions and "bulunamadi" not in extensions:
        print(f"      Mevcut eklentiler: {extensions}")
        print("      ✓ Enigma2 plugins dizini mevcut!")
        return True
    else:
        print("      ✗ Enigma2 plugins dizini bulunamadi!")
        return False

def create_remote_dir(client):
    """Create remote plugin directory."""
    print(f"\n[3/5] Uzak dizin olusturuluyor: {REMOTE_BASE}")
    stdin, stdout, stderr = client.exec_command(f"mkdir -p {REMOTE_BASE}")
    stderr_output = stderr.read().decode().strip()
    if stderr_output:
        print(f"      Uyari: {stderr_output}")
    
    stdin, stdout, stderr = client.exec_command(f"ls -la {os.path.dirname(REMOTE_BASE)}")
    output = stdout.read().decode().strip()
    print(f"      ✓ Dizin olusturuldu!")
    return True

def upload_files(client):
    """Upload plugin files to device."""
    print("\n[4/5] Plugin dosyalari yukleniyor...")
    
    sftp = client.open_sftp()
    
    files_to_upload = [
        "__init__.py",
        "plugin.py",
        "translation_engines.py",
        "subtitle_manager.py",
        "subtitle_overlay.py",
        "utils.py",
        "install.sh",
        "README.md"
    ]
    
    uploaded = 0
    for filename in files_to_upload:
        local_path = os.path.join(PLUGIN_DIR, filename)
        remote_path = f"{REMOTE_BASE}/{filename}"
        
        if os.path.exists(local_path):
            try:
                sftp.put(local_path, remote_path)
                print(f"      ✓ {filename} yuklendi")
                uploaded += 1
            except Exception as e:
                print(f"      ✗ {filename} yuklenemedi: {e}")
        else:
            print(f"      ✗ {filename} bulunamadi!")
    
    sftp.close()
    print(f"\n      Toplam {uploaded}/{len(files_to_upload)} dosya yuklendi")
    return uploaded == len(files_to_upload)

def set_permissions(client):
    """Set file permissions."""
    print("\n[5/5] Dosya izinleri ayarlaniyor...")
    
    commands = [
        f"chmod -R 755 {REMOTE_BASE}",
        f"chown -R root:root {REMOTE_BASE}",
    ]
    
    for cmd in commands:
        stdin, stdout, stderr = client.exec_command(cmd)
        stderr.read()
    
    # Verify files
    stdin, stdout, stderr = client.exec_command(f"ls -la {REMOTE_BASE}")
    output = stdout.read().decode().strip()
    print(f"      ✓ Izinler ayarlandi!")
    print(f"\n      Dosya listesi:")
    for line in output.split('\n'):
        print(f"        {line}")

def restart_enigma(client):
    """Ask and restart Enigma2."""
    print("\n" + "="*50)
    print("  Plugin basariyla yuklendi!")
    print("="*50)
    
    restart = input("\n  Enigma2'yi simdi yeniden baslatmak ister misiniz? (e/h): ").strip().lower()
    
    if restart in ('e', 'evet', 'yes', 'y'):
        print("\n  Enigma2 yeniden baslatiliyor...")
        client.exec_command("killall -9 enigma2")
        print("  ✓ Enigma2 yeniden baslatildi!")
        print("  Lutfen TV'nizde 30-60 saniye bekleyin.")
        print("  Ardindan Menu > Eklentiler > AI AltYazi Ceviri 'ye gidin.")
    else:
        print("\n  Enigma2 elle yeniden baslatilmali.")
        print("  Yeniden baslatmak icin: killall -9 enigma2")

def main():
    print("="*50)
    print("  AI AltYazi Ceviri Plugin - Kurulum")
    print(f"  Hedef: {DEVICE_IP} (Zgemma H9 Twin SE)")
    print("="*50)
    
    # Create SSH connection
    client = create_ssh_client()
    
    try:
        # Check device
        if not check_device(client):
            print("\nCihazdogrulanamadi! Devam etmek istiyor musunuz?")
            cont = input("(e/h): ").strip().lower()
            if cont not in ('e', 'evet', 'yes', 'y'):
                return
        
        # Create directory
        create_remote_dir(client)
        
        # Upload files
        if not upload_files(client):
            print("\nBazi dosyalar yuklenemedi! Kontrol edin.")
            return
        
        # Set permissions
        set_permissions(client)
        
        # Restart
        restart_enigma(client)
        
    except Exception as e:
        print(f"\nHata: {e}")
    finally:
        client.close()

if __name__ == "__main__":
    main()
