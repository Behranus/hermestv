#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  ExoPlayer Auto-Patch — OkHttp + 5dk buffer
#  Her 'flutter pub get' sonrasında çalıştır:
#    bash scripts/patch_exoplayer.sh
# ═══════════════════════════════════════════════════════════════
set -e

VIDEO_PLAYER_DIR=$(find ~/.pub-cache/hosted/pub.dev/ -maxdepth 1 -name "video_player_android*" -type d | sort -V | tail -1)

if [ -z "$VIDEO_PLAYER_DIR" ]; then
    echo "❌ video_player_android bulunamadı!"
    exit 1
fi

echo "📦 Patch uygulanıyor: $VIDEO_PLAYER_DIR"

# ─── 1. OkHttp dependency ekle ───
GRADLE_FILE="$VIDEO_PLAYER_DIR/android/build.gradle.kts"
if [ -f "$GRADLE_FILE" ] && ! grep -q "media3-datasource-okhttp" "$GRADLE_FILE"; then
    echo "🔧 OkHttp dependency ekleniyor..."
    sed -i 's|implementation("androidx.media3:media3-exoplayer-hls:${exoplayerVersion}")|implementation("androidx.media3:media3-exoplayer-hls:${exoplayerVersion}")\n        implementation("androidx.media3:media3-datasource-okhttp:${exoplayerVersion}")|' "$GRADLE_FILE"
    echo "  ✅ OkHttp eklendi"
fi

# ─── 2. TextureVideoPlayer.java patch ───
TEXTURE_FILE=$(find "$VIDEO_PLAYER_DIR" -name "TextureVideoPlayer.java" | head -1)
if [ -n "$TEXTURE_FILE" ]; then
    echo "🔧 TextureVideoPlayer.java patch ediliyor..."
    python3 << 'PYEOF'
import os, re

path = os.environ.get("TEXTURE_FILE", "")
if not path:
    # find it
    import subprocess
    result = subprocess.run(["find", os.path.expanduser("~/.pub-cache/hosted/pub.dev/"), "-maxdepth", "1", "-name", "video_player_android*", "-type", "d"], capture_output=True, text=True)
    base = result.stdout.strip().split("\n")[-1]
    path = os.path.join(base, "android/src/main/java/io/flutter/plugins/videoplayer/texture/TextureVideoPlayer.java")

with open(path, 'r') as f:
    content = f.read()

# OkHttp import ekle
if 'OkHttpDataSource' not in content:
    content = content.replace(
        'import androidx.media3.exoplayer.DefaultLoadControl;',
        '''import androidx.media3.exoplayer.DefaultLoadControl;
import androidx.media3.datasource.okhttp.OkHttpDataSource;
import okhttp3.OkHttpClient;
import okhttp3.ConnectionSpec;
import java.util.Arrays;
import java.util.concurrent.TimeUnit;'''
    )

# OkHttp + Large Buffer builder
old = '''          ExoPlayer.Builder builder = new ExoPlayer.Builder(context);
          // IPTV: 5 dakika buffer — kesintisiz canli yayin
          DefaultLoadControl loadControl =
              new DefaultLoadControl.Builder()
                  .setBufferDurationsMs(
                      15000,   // minBufferMs: 15 saniye — surekli indir
                      60000,   // maxBufferMs: 1 dakika — kucuk buffer = surekli yenile
                      10000,   // bufferForPlaybackMs: 10 saniye — hizli baslangic
                      15000)   // bufferForPlaybackAfterRebufferMs: 15 saniye — cabuk donus
                  .setBackBuffer(300000, true)  // 5 dakika geri tamponlama
                  .build();
          builder.setLoadControl(loadControl);
          androidx.media3.exoplayer.trackselection.DefaultTrackSelector trackSelector =
              new androidx.media3.exoplayer.trackselection.DefaultTrackSelector(context);
          builder
              .setTrackSelector(trackSelector)
            
              .setMediaSourceFactory(asset.getMediaSourceFactory(context));'''

new = '''          OkHttpClient okHttpClient = new OkHttpClient.Builder()
              .connectTimeout(30, TimeUnit.SECONDS)
              .readTimeout(0, TimeUnit.SECONDS)
              .retryOnConnectionFailure(true)
              .connectionSpecs(Arrays.asList(ConnectionSpec.MODERN_TLS, ConnectionSpec.CLEARTEXT))
              .build();
          OkHttpDataSource.Factory okHttpFactory = new OkHttpDataSource.Factory(okHttpClient)
              .setUserAgent("Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0 Mobile Safari/537.36")
              .setAllowCrossProtocolRedirects(true);
          androidx.media3.exoplayer.source.DefaultMediaSourceFactory msf =
              new androidx.media3.exoplayer.source.DefaultMediaSourceFactory(okHttpFactory);
          DefaultLoadControl loadControl =
              new DefaultLoadControl.Builder()
                  .setBufferDurationsMs(30000, 300000, 15000, 30000)
                  .setBackBuffer(300000, true)
                  .build();
          ExoPlayer.Builder builder = new ExoPlayer.Builder(context)
              .setLoadControl(loadControl)
              .setMediaSourceFactory(msf);'''

if old in content:
    content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)
    print("  ✅ TextureVideoPlayer.java patch edildi")
else:
    # Onceki patch'leri temizle ve yeniden uygula
    print("  ⏭️  Zaten patch'li veya eski format")
PYEOF
fi

echo ""
echo "✅ Patch tamamlandı!"
echo "   - OkHttp: readTimeout=0 (asla timeout yok)"
echo "   - Buffer: 30sn min, 300sn max (5 DAKIKA!)"
echo "   - Reconnect: otomatik"
