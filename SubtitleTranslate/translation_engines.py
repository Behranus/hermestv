# -*- coding: utf-8 -*-
"""
Translation Engines for SubtitleTranslate Plugin
Supports: Google Translate (free), DeepL API, Groq Whisper (speech-to-text + translation)
"""

import json
import urllib.request
import urllib.parse
import urllib.error
import ssl
import os
import struct
import tempfile


class TranslationEngineBase:
    """Base class for translation engines."""

    def translate(self, text, source_lang, target_lang):
        raise NotImplementedError

    def getName(self):
        return "Base"


class GoogleTranslateEngine(TranslationEngineBase):
    """
    Free Google Translate engine - no API key required.
    Uses the unofficial Google Translate API endpoint.
    """

    API_URL = "https://translate.googleapis.com/translate_a/single"

    def getName(self):
        return "Google Translate (Ücretsiz)"

    def translate(self, text, source_lang="auto", target_lang="tur"):
        if not text or not text.strip():
            return ""

        try:
            params = urllib.parse.urlencode({
                "client": "gtx",
                "sl": source_lang if source_lang != "auto" else "auto",
                "tl": target_lang,
                "dt": "t",
                "q": text,
            })

            url = f"{self.API_URL}?{params}"

            # SSL context for Enigma2's older Python
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE

            req = urllib.request.Request(url, headers={
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            })

            response = urllib.request.urlopen(req, timeout=10, context=ctx)
            data = json.loads(response.read().decode("utf-8"))

            # Parse response
            translated = ""
            if data and len(data) > 0:
                for sentence in data[0]:
                    if sentence[0]:
                        translated += sentence[0]
            return translated.strip()

        except Exception as e:
            print(f"[SubtitleTranslate] Google Translate hatasi: {e}")
            return f"[Hata: {e}]"


class DeepLEngine(TranslationEngineBase):
    """
    DeepL API translation engine - requires API key.
    Free tier available at https://www.deepl.com/pro-api
    """

    API_URL_FREE = "https://api-free.deepl.com/v2/translate"
    API_URL_PRO = "https://api.deepl.com/v2/translate"

    def __init__(self, api_key=""):
        self.api_key = api_key

    def getName(self):
        return "DeepL"

    def translate(self, text, source_lang="auto", target_lang="tur"):
        if not text or not text.strip():
            return ""

        if not self.api_key:
            return "[Hata: DeepL API key gerekli]"

        try:
            # DeepL language code mapping
            lang_map = {
                "auto": None,
                "eng": "EN",
                "deu": "DE",
                "fra": "FR",
                "spa": "ES",
                "ita": "IT",
                "ara": "AR",
                "rus": "RU",
                "jpn": "JA",
                "kor": "KO",
                "zho": "ZH",
                "nld": "NL",
                "swe": "SV",
                "nor": "NO",
                "dan": "DA",
                "fin": "FI",
                "pol": "PL",
                "por": "PT",
                "tur": "TR",
                "ces": "CS",
                "ron": "RO",
                "hun": "HU",
                "ell": "EL",
                "bul": "BG",
                "ukr": "UK",
                "hrv": "HR",
                "slk": "SK",
            }

            tl = lang_map.get(target_lang, target_lang.upper())
            sl = lang_map.get(source_lang)

            # Determine API endpoint
            api_url = self.API_URL_FREE if len(self.api_key) > 30 else self.API_URL_PRO

            post_data = urllib.parse.urlencode({
                "text": text,
                "target_lang": tl,
            }).encode("utf-8")

            if sl:
                post_data += f"&source_lang={sl}".encode("utf-8")

            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE

            req = urllib.request.Request(api_url, data=post_data, headers={
                "Authorization": f"DeepL-Auth-Key {self.api_key}",
                "Content-Type": "application/x-www-form-urlencoded",
            })

            response = urllib.request.urlopen(req, timeout=15, context=ctx)
            data = json.loads(response.read().decode("utf-8"))

            if "translations" in data and len(data["translations"]) > 0:
                return data["translations"][0]["text"]
            return ""

        except Exception as e:
            print(f"[SubtitleTranslate] DeepL hatasi: {e}")
            return f"[Hata: {e}]"


class GroqWhisperEngine(TranslationEngineBase):
    """
    Groq Whisper engine - Speech to Text + Translation.
    First transcribes audio using Whisper, then translates the result.
    This is useful when there are no DVB subtitles in the broadcast.
    Requires Groq API key from https://console.groq.com
    """

    WHISPER_URL = "https://api.groq.com/openai/v1/audio/transcriptions"

    def __init__(self, api_key=""):
        self.api_key = api_key

    def getName(self):
        return "Groq Whisper"

    def translate(self, text, source_lang="auto", target_lang="tur"):
        """If we have text, just translate it using Google Translate."""
        if not text or not text.strip():
            return ""

        # Use Google Translate as fallback for text translation
        google = GoogleTranslateEngine()
        return google.translate(text, source_lang, target_lang)

    def transcribeAudio(self, audio_file_path):
        """
        Transcribe audio file using Groq Whisper API.
        Returns transcribed text.
        """
        if not self.api_key:
            return "[Hata: Groq API key gerekli]"

        try:
            import mimetypes

            boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"

            # Build multipart form data manually
            body = b""
            body += f"--{boundary}\r\n".encode()
            body += b'Content-Disposition: form-data; name="file"\r\n\r\n'

            with open(audio_file_path, "rb") as f:
                body += f.read()

            body += f"\r\n--{boundary}\r\n".encode()
            body += b'Content-Disposition: form-data; name="model"\r\n\r\n'
            body += b"whisper-large-v3-turbo"
            body += f"\r\n--{boundary}\r\n".encode()
            body += b'Content-Disposition: form-data; name="response_format"\r\n\r\n'
            body += b"text"
            body += f"\r\n--{boundary}--\r\n".encode()

            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE

            req = urllib.request.Request(self.WHISPER_URL, data=body, headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": f"multipart/form-data; boundary={boundary}",
            })

            response = urllib.request.urlopen(req, timeout=30, context=ctx)
            return response.read().decode("utf-8").strip()

        except Exception as e:
            print(f"[SubtitleTranslate] Groq Whisper hatasi: {e}")
            return f"[Hata: {e}]"


class DVBSubtitleExtractor:
    """
    Extracts text from DVB subtitle bitmap pages.
    DVB subtitles are transmitted as bitmap images (PGS format).
    This class attempts to extract text using OCR-like approach.
    
    For bitmap-based DVB subtitles, full OCR is complex on a set-top box.
    This implementation provides a framework that works with teletext subtitles
    and can be extended with OCR capabilities.
    """

    def __init__(self):
        self.last_pages = []
        self.current_page_id = -1

    def processTeletextPage(self, page_data):
        """
        Process a teletext subtitle page and extract text.
        Teletext subtitles are text-based and easier to process.
        
        Args:
            page_data: Raw teletext page data (bytes or string)
        Returns:
            Extracted text string
        """
        try:
            if isinstance(page_data, bytes):
                text = page_data.decode("utf-8", errors="ignore")
            else:
                text = str(page_data)

            # Clean teletext control characters
            import re
            # Remove teletext control sequences
            text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', text)
            # Remove double spaces
            text = re.sub(r' +', ' ', text)
            # Remove empty lines
            lines = [l.strip() for l in text.split('\n') if l.strip()]

            return '\n'.join(lines)

        except Exception as e:
            print(f"[SubtitleTranslate] Teletext isleme hatasi: {e}")
            return ""

    def processDVBSubtitle(self, page):
        """
        Process a DVB subtitle page object from Enigma2's subtitle renderer.
        
        Args:
            page: DVB subtitle page object from eDVBSubtitleControl
        Returns:
            Extracted text (may be empty if OCR not available)
        """
        try:
            # DVB subtitle pages contain bitmap regions with text rendered as images
            # Full OCR on set-top box hardware is very resource intensive
            # This is a placeholder for OCR integration
            # In practice, most DVB subtitles on Turkish satellite are teletext-based
            return ""
        except Exception as e:
            print(f"[SubtitleTranslate] DVB subtitle isleme hatasi: {e}")
            return ""


def getEngine(name, api_key=""):
    """
    Factory function to get translation engine by name.
    
    Args:
        name: Engine identifier ("google_free", "deepl", "groq_whisper")
        api_key: API key for paid services
    Returns:
        TranslationEngineBase instance
    """
    engines = {
        "google_free": lambda: GoogleTranslateEngine(),
        "deepl": lambda: DeepLEngine(api_key),
        "groq_whisper": lambda: GroqWhisperEngine(api_key),
    }

    factory = engines.get(name, lambda: GoogleTranslateEngine())
    return factory()
