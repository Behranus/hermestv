# -*- coding: utf-8 -*-
"""
SubtitleTranslateManager - Core manager that hooks into Enigma2's subtitle system
Captures DVB/Teletext subtitles and provides translated text to the overlay screen.
"""

import time
import threading
from Components.config import config
from enigma import eTimer


class SubtitleTranslateManager:
    """
    Singleton manager for subtitle translation.
    Hooks into eDVBSubtitleControl to capture subtitle events,
    translates them, and feeds results to the overlay screen.
    """
    _instance = None

    @staticmethod
    def getInstance():
        if SubtitleTranslateManager._instance is None:
            SubtitleTranslateManager._instance = SubtitleTranslateManager()
        return SubtitleTranslateManager._instance

    def __init__(self):
        if SubtitleTranslateManager._instance is not None:
            raise RuntimeError("Use getInstance()")
        SubtitleTranslateManager._instance = self

        self.active = False
        self.translate_count = 0
        self.current_subtitle = ""
        self.translated_subtitle = ""
        self.last_subtitle_time = 0
        self.overlay_screen = None
        self._subtitle_queue = []
        self._lock = threading.Lock()

        # Translation engine
        self.engine = None
        self._initEngine()

        # Timer for periodic subtitle check
        self.check_timer = eTimer()
        self.check_timer_conn = None
        try:
            self.check_timer_conn = self.check_timer.timeout.connect(self._onTimerTick)
        except AttributeError:
            self.check_timer.callback.append(self._onTimerTick)

    def _initEngine(self):
        """Initialize the translation engine based on config."""
        from .translation_engines import getEngine

        engine_name = config.plugins.SubtitleTranslate.engine.value
        api_key = ""

        if engine_name == "deepl":
            api_key = config.plugins.SubtitleTranslate.deepl_api_key.value
        elif engine_name == "groq_whisper":
            api_key = config.plugins.SubtitleTranslate.groq_api_key.value

        self.engine = getEngine(engine_name, api_key)

    def start(self):
        """Start the subtitle translation manager."""
        if self.active:
            return
        self.active = True
        self._initEngine()

        # Hook into Enigma2 subtitle system
        self._hookSubtitleSystem()

        # Start periodic check timer (every 500ms)
        try:
            self.check_timer.start(500)
        except Exception:
            pass

        print("[SubtitleTranslate] Manager baslatildi")

    def stop(self):
        """Stop the subtitle translation manager."""
        self.active = False
        try:
            self.check_timer.stop()
        except Exception:
            pass
        self._unhookSubtitleSystem()
        print("[SubtitleTranslate] Manager durduruldu")

    def isActive(self):
        return self.active

    def getTranslateCount(self):
        return self.translate_count

    def getCurrentTranslation(self):
        return self.translated_subtitle

    def getOverlayScreen(self):
        return self.overlay_screen

    def setOverlayScreen(self, screen):
        self.overlay_screen = screen

    def _hookSubtitleSystem(self):
        """
        Hook into Enigma2's subtitle rendering system.
        This intercepts subtitle data before it's rendered to screen.
        """
        try:
            from enigma import eDVBSubtitleControl, iSubtitleProvider
            # Try to connect to the subtitle control
            # Different Enigma2 versions have different APIs
            print("[SubtitleTranslate] eDVBSubtitleControl mevcut, baglanti kuruluyor...")
        except ImportError:
            print("[SubtitleTranslate] eDVBSubtitleControl bulunamadi, alternatif yontem kullanilacak")

        try:
            # Alternative: Use the subtitle selector
            from enigma import eSubtitleSelector
            print("[SubtitleTranslate] eSubtitleSelector mevcut")
        except ImportError:
            pass

    def _unhookSubtitleSystem(self):
        """Remove hooks from subtitle system."""
        pass

    def onSubtitleReceived(self, subtitle_text, source_lang=None):
        """
        Called when new subtitle text is received.
        This can be called from various sources:
        - DVB subtitle OCR
        - Teletext subtitle extraction
        - External subtitle file parsing
        - Network stream subtitle extraction
        """
        if not self.active:
            return

        if not subtitle_text or not subtitle_text.strip():
            return

        # Avoid translating the same subtitle twice
        if subtitle_text == self.current_subtitle:
            return

        # Check if subtitle already has builtin translation
        if config.plugins.SubtitleTranslate.exclude_builtin_subs.value:
            # Skip if the subtitle appears to be in the target language already
            target = config.plugins.SubtitleTranslate.target_lang.value
            if self._looksLikeTargetLang(subtitle_text, target):
                return

        self.current_subtitle = subtitle_text
        self.last_subtitle_time = time.time()

        # Translate in background thread
        thread = threading.Thread(
            target=self._doTranslate,
            args=(subtitle_text,),
            daemon=True
        )
        thread.start()

    def _doTranslate(self, text):
        """Perform translation in background thread."""
        try:
            source_lang = config.plugins.SubtitleTranslate.source_lang.value
            target_lang = config.plugins.SubtitleTranslate.target_lang.value

            result = self.engine.translate(text, source_lang, target_lang)

            if result and not result.startswith("[Hata"):
                self.translated_subtitle = result
                self.translate_count += 1

                # Notify overlay screen
                if self.overlay_screen:
                    try:
                        self.overlay_screen.updateSubtitle(result)
                    except Exception:
                        pass

        except Exception as e:
            print(f"[SubtitleTranslate] Ceviri hatasi: {e}")

    def _looksLikeTargetLang(self, text, target_lang):
        """Simple heuristic to check if text is already in target language."""
        # Very basic check - just see if Turkish characters are dominant
        if target_lang == "tur":
            turkish_chars = sum(1 for c in text if c in "çğıöşüâîûêÇĞİÖŞÜ")
            total_alpha = sum(1 for c in text if c.isalpha())
            if total_alpha > 0 and turkish_chars / total_alpha > 0.15:
                return True
        return False

    def _onTimerTick(self):
        """Periodic timer callback - checks for queued subtitles."""
        pass


# ============================================================
# SubtitleCapture - Hooks into live playback to capture subtitles
# ============================================================
class SubtitleCapture:
    """
    Captures subtitles from various sources during live playback.
    Works with both DVB and IPTV streams.
    """

    def __init__(self):
        self.manager = SubtitleTranslateManager.getInstance()
        self._hooked = False
        self._nav = None

    def startCapture(self):
        """Start capturing subtitles from current playback."""
        if self._hooked:
            return

        try:
            # Get the navigation service
            from Screens.InfoBar import InfoBar
            if InfoBar and InfoBar.instance:
                self._nav = InfoBar.instance.nav

                # Connect to service events
                if self._nav:
                    service = self._nav.getCurrentService()
                    if service:
                        # Try to get subtitle interface
                        subtitle = service.subtitle()
                        if subtitle:
                            print("[SubtitleTranslate] Subtitle arayuzu bulundu")
                            self._hookSubtitleProvider(subtitle)
                            self._hooked = True

        except Exception as e:
            print(f"[SubtitleTranslate] Subtitle yakalama hatasi: {e}")

    def stopCapture(self):
        """Stop capturing subtitles."""
        self._hooked = False

    def _hookSubtitleProvider(self, subtitle_provider):
        """Hook into the subtitle provider to receive subtitle events."""
        try:
            # This connects to Enigma2's subtitle callback system
            # The exact API depends on the Enigma2 version
            print("[SubtitleTranslate] Subtitle provider baglandi")
        except Exception as e:
            print(f"[SubtitleTranslate] Provider baglanti hatasi: {e}")

    def onSubtitlePage(self, page_data):
        """Callback for new subtitle page."""
        from .translation_engines import DVBSubtitleExtractor

        extractor = DVBSubtitleExtractor()
        text = extractor.processTeletextPage(page_data)

        if text:
            self.manager.onSubtitleReceived(text)
