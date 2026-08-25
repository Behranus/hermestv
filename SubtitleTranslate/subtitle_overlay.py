# -*- coding: utf-8 -*-
"""
SubtitleOverlay - Transparent overlay screen that displays translated subtitles
on top of the video playback.
"""

from Screens.Screen import Screen
from Components.config import config
from enigma import eLabel, eTimer, RT_HALIGN_CENTER, RT_VALIGN_BOTTOM


class SubtitleOverlay(Screen):
    """
    Transparent overlay that shows translated subtitles.
    Positioned on top of the video with configurable appearance.
    """

    # Dynamic skin based on config
    def __init__(self, session):
        Screen.__init__(self, session)

        # Get positioning config
        position = config.plugins.SubtitleTranslate.position.value
        font_size = config.plugins.SubtitleTranslate.font_size.value

        # Font size mapping
        size_map = {
            "small": 20,
            "medium": 26,
            "large": 34,
        }
        fsize = size_map.get(font_size, 26)

        # Position mapping
        pos_map = {
            "bottom": ("center", "bottom"),
            "top": ("center", "top"),
            "center": ("center", "center"),
        }
        halign, valign = pos_map.get(position, ("center", "bottom"))

        # Build dynamic skin
        if valign == "bottom":
            widget_pos = "50,540"
            widget_size = "1180,120"
        elif valign == "top":
            widget_pos = "50,20"
            widget_size = "1180,120"
        else:
            widget_pos = "50,300"
            widget_size = "1180,120"

        self.skin = f"""
            <screen name="SubtitleOverlay" position="0,0" size="1280,720" flags="wfNoBorder" backgroundColor="transparent">
                <widget name="subtitle_text" position="{widget_pos}" size="{widget_size}"
                    font="Regular;{fsize}" halign="center" valign="bottom"
                    foregroundColor="white" backgroundColor="#80000000"
                    transparent="1" noWrap="0" />
                <widget name="original_text" position="{widget_pos}" size="{widget_size}"
                    font="Regular;{fsize - 4}" halign="center" valign="top"
                    foregroundColor="#aaffffff" backgroundColor="#80000000"
                    transparent="1" noWrap="0" />
            </screen>
        """

        self["subtitle_text"] = eLabel(self)
        self["original_text"] = eLabel(self)

        # Initialize with empty
        self["subtitle_text"].setText("")
        self["original_text"].setText("")

        # Auto-hide timer
        self.hide_timer = eTimer()
        try:
            self.hide_timer_conn = self.hide_timer.timeout.connect(self._hideSubtitle)
        except AttributeError:
            self.hide_timer.callback.append(self._hideSubtitle)

        # Register with manager
        from .subtitle_manager import SubtitleTranslateManager
        self.manager = SubtitleTranslateManager.getInstance()
        self.manager.setOverlayScreen(self)

    def updateSubtitle(self, translated_text, original_text=""):
        """Update the displayed subtitle text."""
        try:
            max_lines = config.plugins.SubtitleTranslate.max_lines.value
            lines = translated_text.split('\n')
            if len(lines) > max_lines:
                lines = lines[:max_lines]
                translated_text = '\n'.join(lines)

            self["subtitle_text"].setText(translated_text)

            if original_text:
                self["original_text"].setText(original_text)
            else:
                self["original_text"].setText("")

            # Show overlay
            self.show()

            # Reset hide timer (8 seconds)
            try:
                self.hide_timer.startLongTimer(8)
            except Exception:
                self.hide_timer.start(8000)

        except Exception as e:
            print(f"[SubtitleOverlay] Guncelleme hatasi: {e}")

    def _hideSubtitle(self):
        """Hide the subtitle after timeout."""
        try:
            self["subtitle_text"].setText("")
            self["original_text"].setText("")
            self.hide()
        except Exception:
            pass

    def clearSubtitle(self):
        """Immediately clear the subtitle."""
        self._hideSubtitle()
        try:
            self.hide_timer.stop()
        except Exception:
            pass


class SubtitleTranslateMenuScreen(Screen):
    """
    Quick-access menu for toggling subtitle translation during playback.
    Accessible via a configurable hotkey or the extension menu.
    """
    skin = """
        <screen name="SubtitleTranslateMenuScreen" position="center,center" size="600,400" title="Altyazi Ceviri Kontrol">
            <widget name="status" position="30,30" size="540,60" font="Regular;24" halign="center" />
            <widget name="toggle_text" position="30,120" size="540,50" font="Regular;22" />
            <widget name="engine_text" position="30,180" size="540,50" font="Regular;22" />
            <widget name="lang_text" position="30,240" size="540,50" font="Regular;22" />
            <widget name="count_text" position="30,300" size="540,50" font="Regular;22" />
        </screen>
    """

    def __init__(self, session):
        Screen.__init__(self, session)

        from .subtitle_manager import SubtitleTranslateManager
        self.manager = SubtitleTranslateManager.getInstance()

        self["toggle_text"] = eLabel(self)
        self["engine_text"] = eLabel(self)
        self["lang_text"] = eLabel(self)
        self["count_text"] = eLabel(self)

        self.updateDisplay()

        from Components.ActionMap import ActionMap
        self["actions"] = ActionMap(["OkCancelActions", "NumberActions"], {
            "ok": self.toggleTranslation,
            "cancel": self.close,
            "1": self.toggleTranslation,
            "2": self.cycleEngine,
        }, -2)

    def updateDisplay(self):
        """Update the display with current settings."""
        active = self.manager.isActive()
        engine = config.plugins.SubtitleTranslate.engine.value
        target = config.plugins.SubtitleTranslate.target_lang.value
        count = self.manager.getTranslateCount()

        engine_names = {
            "google_free": "Google Translate (Ucretsiz)",
            "deepl": "DeepL",
            "groq_whisper": "Groq Whisper",
        }
        lang_names = {
            "tur": "Turkce", "eng": "Ingilizce", "deu": "Almanca",
            "fra": "Fransizca", "ara": "Arapca", "rus": "Rusca",
        }

        status = "AKTIF" if active else "PASIF"
        color = "green" if active else "red"

        try:
            self["status"].setText(f"Durum: [{status}]")
            self["toggle_text"].setText(f"[1] {'Durdur' if active else 'Baslat'}")
            self["engine_text"].setText(f"[2] Motor: {engine_names.get(engine, engine)}")
            self["lang_text"].setText(f"Hedef: {lang_names.get(target, target)}")
            self["count_text"].setText(f"Cevrilen: {count} altyazi")
        except Exception:
            pass

    def toggleTranslation(self):
        """Toggle translation on/off."""
        if self.manager.isActive():
            self.manager.stop()
        else:
            self.manager.start()
        self.updateDisplay()

    def cycleEngine(self):
        """Cycle through available engines."""
        engines = ["google_free", "deepl", "groq_whisper"]
        current = config.plugins.SubtitleTranslate.engine.value
        idx = engines.index(current) if current in engines else 0
        next_idx = (idx + 1) % len(engines)
        config.plugins.SubtitleTranslate.engine.value = engines[next_idx]
        self.manager._initEngine()
        self.updateDisplay()
