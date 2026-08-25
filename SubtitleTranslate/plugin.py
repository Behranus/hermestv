# -*- coding: utf-8 -*-
# BB AI Sub v4 - DVB Subtitle Translator using Groq Vision
# ffmpeg DVB extraction → Groq Vision OCR → Google Translate
# Uses existing Groq API key - no additional keys needed!

import os, json, hashlib, io, struct, time
import urllib.parse

from Plugins.Plugin import PluginDescriptor
from Screens.Screen import Screen
from Screens.MessageBox import MessageBox
from Components.Label import Label
from Components.ActionMap import ActionMap
from Components.ConfigList import ConfigListScreen
from Components.config import config, ConfigSubsection, ConfigSelection, ConfigYesNo, getConfigListEntry
from enigma import eTimer, eConsoleAppContainer

config.plugins.BBAIVision = ConfigSubsection()
config.plugins.BBAIVision.enabled = ConfigYesNo(default=False)
config.plugins.BBAIVision.target_lang = ConfigSelection(default='tr', choices=[
    ('tr', 'Türkçe'), ('en', 'English'), ('de', 'Deutsch'),
    ('fr', 'Français'), ('ar', 'العربية'), ('ru', 'Русский'),
])

_dvb = None

class DVBVisionTranslator:
    """Extract DVB subtitles via ffmpeg, OCR with Groq Vision, translate with Google."""

    def __init__(self, session):
        self.session = session
        self.running = False
        self.last_text = ''
        self.cycle = 0
        self.lang = config.plugins.BBAIVision.target_lang.value
        self.timer = eTimer()
        self.timer.callback.append(self._poll)
        self.console = eConsoleAppContainer()
        self.console.appClosed.append(self._done)
        self.stage = 'idle'
        self.status_label = None
        self.groq_key = ''
        self._load_groq_key()

    def _load_groq_key(self):
        for path in ['/etc/enigma2/aisubtitles/groq.key', '/tmp/groq.key']:
            try:
                with open(path) as f:
                    self.groq_key = f.read().strip()
                    if self.groq_key:
                        return
            except:
                pass

    def start(self):
        if self.running:
            return
        if not self.groq_key:
            self._status('No Groq key!')
            return
        self.running = True
        self.cycle = 0
        self.last_text = ''
        self._status('Starting...')
        self.timer.start(2000)

    def stop(self):
        self.running = False
        self.timer.stop()
        try:
            self.console.kill()
        except:
            pass
        # Kill any lingering ffmpeg
        os.system('killall -9 ffmpeg 2>/dev/null')

    def _poll(self):
        if not self.running or self.stage != 'idle':
            return
        self._extract_subtitle()

    def _extract_subtitle(self):
        """Use ffmpeg to extract DVB subtitle bitmap from live stream."""
        try:
            svc = self.session.nav.getCurrentlyPlayingServiceReference()
            if not svc:
                self._retry(2000)
                return
            sref = svc.toString()

            # Build ffmpeg command to extract subtitle frame
            # Use enigma2's HTTP proxy to access the stream
            stream_url = 'http://127.0.0.1:8001/{}'.format(sref.replace(' ', '%20'))

            # ffmpeg: extract subtitle stream, decode DVB subtitles, output as JPEG
            # -map 0:s:0 = first subtitle stream
            # -c:s dvbsub = DVB subtitle decoder
            # -f image2 = output as image
            # -update 1 = overwrite file each frame
            cmd = 'timeout 5 ffmpeg -loglevel quiet -i "{}" -map 0:s:0 -c:s dvbsub -f image2 -update 1 -y /tmp/dvb_sub.jpg 2>/dev/null'.format(stream_url)

            self.stage = 'extract'
            self.console.execute(cmd)
            self.timer.start(6000, True)

        except Exception as e:
            self._status('Extract err: {}'.format(str(e)[:20]))
            self._retry(3000)

    def _done(self, retval):
        self.timer.stop()
        if not self.running:
            return

        if self.stage == 'extract':
            # Check if we got a subtitle image
            if os.path.exists('/tmp/dvb_sub.jpg') and os.path.getsize('/tmp/dvb_sub.jpg') > 1000:
                self.stage = 'ocr'
                self._status('OCR (Groq Vision)...')
                self._ocr_with_groq_vision()
            else:
                # No subtitle found, try again
                self.stage = 'idle'
                self._retry(1500)

        elif self.stage == 'ocr':
            self._handle_ocr()

        elif self.stage == 'translate':
            self._handle_translate()

    def _ocr_with_groq_vision(self):
        """Send subtitle image to Groq Vision model for OCR."""
        try:
            with open('/tmp/dvb_sub.jpg', 'rb') as f:
                img_data = f.read()

            b64 = __import__('base64').b64encode(img_data).decode()

            payload = {
                'model': 'qwen/qwen3.6-27b',
                'messages': [{
                    'role': 'user',
                    'content': [
                        {'type': 'text', 'text': 'Read the text in this subtitle image. Return ONLY the text, nothing else. No explanations, no quotes, just the raw text.'},
                        {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,{}'.format(b64)}}
                    ]
                }],
                'max_tokens': 200
            }

            with open('/tmp/groq_vision_payload.json', 'w') as f:
                json.dump(payload, f)

            cmd = 'curl -k -s --max-time 15 -X POST "https://api.groq.com/openai/v1/chat/completions" -H "Authorization: Bearer {}" -H "Content-Type: application/json" -d @/tmp/groq_vision_payload.json > /tmp/groq_vision_result.json'.format(self.groq_key)

            self.console.execute(cmd)
            self.timer.start(16000, True)

        except Exception as e:
            self._status('Vision err: {}'.format(str(e)[:20]))
            self.stage = 'idle'
            self._retry(2000)

    def _handle_ocr(self):
        """Parse Groq Vision result and translate."""
        try:
            with open('/tmp/groq_vision_result.json') as f:
                data = json.load(f)

            text = data['choices'][0]['message']['content'].strip()

            # Clean up the text
            text = text.strip('"\'')
            if not text or len(text) < 2:
                self.stage = 'idle'
                self._retry(1500)
                return

            if text == self.last_text:
                self.stage = 'idle'
                self._retry(1500)
                return

            self.last_text = text
            self.stage = 'translate'
            self._status('Translating...')
            self._translate(text)

        except Exception as e:
            self._status('Parse err')
            self.stage = 'idle'
            self._retry(2000)

    def _translate(self, text):
        """Translate with Google Translate (free, no API key)."""
        params = urllib.parse.urlencode({
            'client': 'gtx', 'sl': 'auto', 'tl': self.lang, 'dt': 't', 'q': text
        })
        cmd = 'curl -k -s --max-time 8 "https://translate.googleapis.com/translate_a/single?{}" > /tmp/dvb_tl.json'.format(params)
        self.console.execute(cmd)
        self.timer.start(9000, True)

    def _handle_translate(self):
        try:
            with open('/tmp/dvb_tl.json') as f:
                data = json.load(f)
            translated = ''.join(p[0] for p in data[0] if p[0])
            if translated:
                self.cycle += 1
                self._status('[{}] {}'.format(self.cycle, translated))
        except:
            pass
        self.stage = 'idle'
        self._retry(500)

    def _retry(self, delay):
        if self.running:
            t = eTimer()
            t.callback.append(self._poll)
            t.start(delay, True)

    def _status(self, t):
        print('[BB AI Sub] {}'.format(t))
        if self.status_label:
            try:
                self.status_label.setText(t)
            except:
                pass


class BBAIVisionSettings(ConfigListScreen, Screen):
    skin = '''<screen name="BBAIVisionSettings" position="center,center" size="700,320"
            title="BB AI Sub - DVB Vision Translator" backgroundColor="#99000000">
        <widget name="config" position="20,30" size="660,210" scrollbarMode="showOnDemand"
                backgroundColor="#40000000" itemHeight="36" />
        <widget name="status" position="20,250" size="660,30" font="Regular;18"
                foregroundColor="#00ff00" backgroundColor="transparent" />
        <widget name="key_red" position="20,285" size="150,30" font="Regular;16"
                halign="center" backgroundColor="#cc0000" foregroundColor="white" />
        <widget name="key_green" position="185,285" size="150,30" font="Regular;16"
                halign="center" backgroundColor="#00aa00" foregroundColor="white" />
        <widget name="key_yellow" position="350,285" size="150,30" font="Regular;16"
                halign="center" backgroundColor="#ccaa00" foregroundColor="white" />
    </screen>'''

    def __init__(self, session):
        Screen.__init__(self, session)
        self.list = [
            getConfigListEntry('Enable', config.plugins.BBAIVision.enabled),
            getConfigListEntry('Target Language', config.plugins.BBAIVision.target_lang),
        ]
        ConfigListScreen.__init__(self, self.list)
        self['key_red'] = Label('Close')
        self['key_green'] = Label('Save')
        self['key_yellow'] = Label('Start')
        self['status'] = Label('')
        self['actions'] = ActionMap(['ColorActions', 'SetupActions'], {
            'red': self.close, 'green': self.save_close,
            'yellow': self.toggle, 'cancel': self.close,
        }, -2)

        global _dvb
        if _dvb and _dvb.running:
            self['key_yellow'].setText('Stop')
            self['status'].setText('RUNNING - Groq Key: YES' if _dvb.groq_key else 'No Groq Key!')

    def save_close(self):
        for e in self.list:
            e[1].save()
        config.plugins.BBAIVision.save()
        self.close()

    def toggle(self):
        global _dvb
        if not _dvb:
            _dvb = DVBVisionTranslator(self.session)
        _dvb.status_label = self['status']

        if _dvb.running:
            _dvb.stop()
            self['key_yellow'].setText('Start')
            self['status'].setText('Stopped')
        else:
            _dvb.start()
            self['key_yellow'].setText('Stop')
            if _dvb.running:
                self.close()


def main(session, **kw):
    session.open(BBAIVisionSettings)

def start_toggle(session, **kw):
    global _dvb
    if not _dvb:
        _dvb = DVBVisionTranslator(session)
    if _dvb.running:
        _dvb.stop()
        session.open(MessageBox, 'BB AI Sub Stopped', MessageBox.TYPE_INFO, timeout=2)
    else:
        _dvb.start()
        session.open(MessageBox, 'BB AI Sub Started!\nDVB subtitles will be translated.', MessageBox.TYPE_INFO, timeout=3)

def Plugins(**kw):
    return [
        PluginDescriptor(name='BB AI Sub', description='DVB Vision Subtitle Translator',
            where=PluginDescriptor.WHERE_PLUGINMENU, icon='plugin.png', fnc=main),
        PluginDescriptor(name='BB AI Sub Start/Stop', description='Toggle DVB Translation',
            where=PluginDescriptor.WHERE_EXTENSIONSMENU, fnc=start_toggle),
    ]
