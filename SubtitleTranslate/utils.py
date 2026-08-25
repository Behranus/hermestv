# -*- coding: utf-8 -*-
"""
Utility functions for SubtitleTranslate plugin.
Handles subtitle file parsing, network operations, and device-specific helpers.
"""

import os
import json
import urllib.request
import urllib.parse
import ssl
import time
from Tools.Directories import resolveFilename


def getDeviceType():
    """Detect the device type for optimization."""
    try:
        # Check for common SoC files
        if os.path.exists("/proc/stb/info/chipset"):
            with open("/proc/stb/info/chipset", "r") as f:
                return f.read().strip()
    except Exception:
        pass
    return "unknown"


def isZgemmaH9():
    """Check if running on Zgemma H9 series."""
    device = getDeviceType()
    return "hi3798" in device.lower() or "h9" in device.lower()


def getNetworkSpeed():
    """Estimate network speed for optimal translation batching."""
    try:
        import socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(3)
        start = time.time()
        sock.connect(("translate.googleapis.com", 443))
        latency = time.time() - start
        sock.close()

        if latency < 0.1:
            return "fast"
        elif latency < 0.5:
            return "medium"
        else:
            return "slow"
    except Exception:
        return "medium"


def parseSRT(content):
    """
    Parse SRT subtitle file content.
    Returns list of (index, start_time, end_time, text) tuples.
    """
    entries = []
    blocks = content.strip().split('\n\n')

    for block in blocks:
        lines = block.strip().split('\n')
        if len(lines) >= 3:
            try:
                idx = int(lines[0].strip())
                time_parts = lines[1].strip().split(' --> ')
                if len(time_parts) == 2:
                    text = '\n'.join(lines[2:])
                    entries.append((idx, time_parts[0].strip(), time_parts[1].strip(), text))
            except (ValueError, IndexError):
                continue

    return entries


def parseVTT(content):
    """
    Parse WebVTT subtitle file content.
    Returns list of (start_time, end_time, text) tuples.
    """
    entries = []
    # Remove header
    if content.startswith("WEBVTT"):
        content = content[content.index('\n')+1:]

    blocks = content.strip().split('\n\n')

    for block in blocks:
        lines = block.strip().split('\n')
        for i, line in enumerate(lines):
            if '-->' in line:
                time_parts = line.split(' --> ')
                if len(time_parts) == 2:
                    text = '\n'.join(lines[i+1:])
                    entries.append((time_parts[0].strip(), time_parts[1].strip(), text))
                break

    return entries


def createSettingsBackup():
    """Backup plugin settings."""
    try:
        settings_file = "/etc/enigma2/settings"
        backup_file = "/tmp/subtitle_translate_settings_backup.txt"

        if os.path.exists(settings_file):
            with open(settings_file, "r") as f:
                content = f.read()

            # Extract only SubtitleTranslate settings
            lines = content.split('\n')
            plugin_lines = [l for l in lines if 'SubtitleTranslate' in l]

            with open(backup_file, "w") as f:
                f.write('\n'.join(plugin_lines))

            return backup_file
    except Exception as e:
        print(f"[SubtitleTranslate] Yedekleme hatasi: {e}")
    return None


def restoreSettingsBackup(backup_file):
    """Restore plugin settings from backup."""
    try:
        if not os.path.exists(backup_file):
            return False

        with open(backup_file, "r") as f:
            plugin_lines = f.read().strip().split('\n')

        settings_file = "/etc/enigma2/settings"

        # Read existing settings
        existing_lines = []
        if os.path.exists(settings_file):
            with open(settings_file, "r") as f:
                existing_lines = f.read().strip().split('\n')

        # Remove old SubtitleTranslate settings
        existing_lines = [l for l in existing_lines if 'SubtitleTranslate' not in l]

        # Add backed up settings
        existing_lines.extend(plugin_lines)

        # Write back
        with open(settings_file, "w") as f:
            f.write('\n'.join(existing_lines))

        return True
    except Exception as e:
        print(f"[SubtitleTranslate] Geri yukleme hatasi: {e}")
    return False


def translateBatch(texts, engine, source_lang, target_lang):
    """
    Translate a batch of texts efficiently.
    Groups texts to minimize API calls.
    """
    if not texts:
        return []

    # For Google Translate, batch texts with newline separator
    separator = " ||| "
    batch_text = separator.join(texts)

    result = engine.translate(batch_text, source_lang, target_lang)

    # Split results
    if result and "|||" in result:
        translated = [t.strip() for t in result.split("|||")]
        # Pad if needed
        while len(translated) < len(texts):
            translated.append("")
        return translated[:len(texts)]
    else:
        return [result] * len(texts)
