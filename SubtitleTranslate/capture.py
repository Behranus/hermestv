#!/usr/bin/env python3
import os, sys, json, struct, subprocess

RAW = "/tmp/bbaisub_raw.pcm"
WAV = "/tmp/bbaisub.wav"
RESULT = "/tmp/bbaisub_result.json"
SREF_FILE = "/tmp/bbaisub_sref.txt"

def write_result(text="", error=""):
    with open(RESULT, "w") as f:
        json.dump({"text": text, "error": error}, f)

def get_service_url():
    try:
        with open(SREF_FILE, "r") as f:
            sref = f.read().strip()
        if sref:
            return "http://127.0.0.1:8001/" + sref.replace(" ", "%20")
    except Exception:
        pass
    return None

def record_audio(url):
    for f in [RAW, WAV]:
        try: os.remove(f)
        except: pass
    cmd = f"timeout 3 gst-launch-1.0 -q souphttpsrc location='{url}' ! decodebin ! audioconvert ! audioresample ! audio/x-raw,rate=16000,channels=1,format=S16LE ! filesink location='{RAW}'"
    try:
        subprocess.run(cmd, shell=True, timeout=5, capture_output=True)
    except: pass
    return os.path.exists(RAW) and os.path.getsize(RAW) >= 1024

def pcm_to_wav():
    try:
        raw = open(RAW, "rb").read()
        sr, ch, bits = 16000, 1, 16
        br = sr * ch * 2
        w = bytearray()
        w.extend(b"RIFF"); w.extend(struct.pack("<I", 36+len(raw)))
        w.extend(b"WAVEfmt "); w.extend(struct.pack("<I",16))
        w.extend(struct.pack("<HHIIHH",1,ch,sr,br,ch*2,bits))
        w.extend(b"data"); w.extend(struct.pack("<I",len(raw))); w.extend(raw)
        open(WAV, "wb").write(w)
        return True
    except: return False

def transcribe(key):
    try:
        r = subprocess.run(["curl","-k","-s","--max-time","10","-X","POST",
            "https://api.groq.com/openai/v1/audio/transcriptions",
            "-H","Authorization: Bearer "+key,
            "-F","file=@"+WAV,"-F","model=whisper-large-v3-turbo",
            "-F","response_format=json"], capture_output=True, text=True, timeout=15)
        return r.stdout
    except: return '{"text":""}'

def main():
    key = sys.argv[1] if len(sys.argv) > 1 else ""
    if not key or len(key) < 10:
        write_result("", "no_key"); return
    url = get_service_url()
    if not url:
        write_result("", "no_service"); return
    if not record_audio(url):
        write_result("", "no_audio"); return
    if not pcm_to_wav():
        write_result("", "wav_fail"); return
    resp = transcribe(key)
    try: data = json.loads(resp)
    except: data = {"text": ""}
    with open(RESULT, "w") as f:
        json.dump(data, f)

if __name__ == "__main__":
    try: main()
    except Exception as e:
        try: write_result("", "err:"+str(e)[:30])
        except: pass
