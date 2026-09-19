package com.iptv.iptv_player

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.Surface
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Tracks
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.TrackSelectionParameters
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.DefaultLivePlaybackSpeedControl
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.exoplayer.upstream.DefaultLoadErrorHandlingPolicy
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import okhttp3.OkHttpClient
import okhttp3.ConnectionSpec
import java.util.Arrays
import java.util.concurrent.TimeUnit

// Canli yayinda gecici ag hatalarina karsi daha fazla deneme hakki
private const val MAX_RETRIES = 10

@UnstableApi
class ExoPlayerPlugin(
    private val context: Context,
    private val textureRegistry: TextureRegistry,
    private val messenger: io.flutter.plugin.common.BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "ExoPlayerPlugin"
        private const val CHANNEL = "com.iptv.iptv_player/exo_player"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val methodChannel = MethodChannel(messenger, CHANNEL)
    private val players = mutableMapOf<Long, PlayerInstance>()

    fun register() {
        methodChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> create(call, result)
            "open" -> open(call, result)
            "play" -> play(call, result)
            "pause" -> pause(call, result)
            "stop" -> stop(call, result)
            "seek" -> seek(call, result)
            "setVolume" -> setVolume(call, result)
            "dispose" -> dispose(call, result)
            "getPosition" -> getPosition(call, result)
            "getDuration" -> getDuration(call, result)
            "getAudioTracks" -> getAudioTracks(call, result)
            "getSubtitleTracks" -> getSubtitleTracks(call, result)
            "selectAudioTrack" -> selectAudioTrack(call, result)
            "selectSubtitleTrack" -> selectSubtitleTrack(call, result)
            "getPlaybackMetrics" -> getPlaybackMetrics(call, result)
            else -> result.notImplemented()
        }
    }

    @UnstableApi
    private fun create(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId")
            ?: return result.error("MISSING", "textureId", null)

        mainHandler.post {
            try {
                val surfaceProducer = textureRegistry.createSurfaceProducer()

                // OkHttp — canlı IPTV bağlantısı
                // ONEMLI: readTimeout 10sn idi. OkHttp read timeout, soket uzerinde
                // iki okuma arasindaki AZAMI sessizliktir. Canli HLS'de segment suresi
                // tipik olarak ~10sn'dir; sunucu segmenti gec urettiginde aradaki
                // sessizlik 10sn'yi asiyor -> SocketTimeoutException -> onPlayerError ->
                // bastan prepare() (gorunur reload). Gozlenen ~10sn'lik dongunun kaynagi bu.
                val okHttpClient = OkHttpClient.Builder()
                    .connectTimeout(15, TimeUnit.SECONDS)   // olu sunucuda daha hizli vazgec
                    .readTimeout(30, TimeUnit.SECONDS)      // segment arasi sessizligi tolere et
                    .writeTimeout(15, TimeUnit.SECONDS)
                    .retryOnConnectionFailure(true)
                    .connectionSpecs(Arrays.asList(
                        ConnectionSpec.MODERN_TLS,
                        ConnectionSpec.CLEARTEXT
                    ))
                    .build()

                // Zaman asimlari OkHttpClient uzerinde ayarli (yukarida);
                // OkHttpDataSource.Factory'de ayri setter yok.
                val okHttpFactory = OkHttpDataSource.Factory(okHttpClient)
                    .setUserAgent("Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36")

                // Canli hedef ofset: live edge'in 15sn gerisi. Bu deger kasitli olarak
                // yuksek tutuldu — 5sn'lik ofset her sunucu dalgalanmasinda live edge'e
                // carpip takilmaya yol aciyordu. Daha buyuk ofset = daha fazla guvenlik
                // payi (takilma direnci). Dusurmek takilmayi ARTIRIR, bu yuzden 15sn.
                // Ek olarak: segment/ağ hatalarini ExoPlayer kendi icinde sessizce tekrar
                // dener (gorunur reload yerine kesintisiz akis).
                val mediaSourceFactory = DefaultMediaSourceFactory(okHttpFactory)
                    .setLiveTargetOffsetMs(15000)
                    .setLoadErrorHandlingPolicy(DefaultLoadErrorHandlingPolicy(10))

                // Canli yayin buffer'i — orijinal dayanikli degerler korundu;
                // yalnizca rebuffer sonrasi devam esigi 3sn -> 2.5sn (daha hizli donus)
                val loadControl = DefaultLoadControl.Builder()
                    .setBufferDurationsMs(
                        25000,   // minBufferMs — sunucu takilmalarini emen tampon
                        300000,  // maxBufferMs (5 dk)
                        3000,    // bufferForPlaybackMs
                        2500     // bufferForPlaybackAfterRebufferMs — 2.5sn'de devam
                    )
                    .setBackBuffer(300000, true)
                    .setPrioritizeTimeOverSizeThresholds(true)
                    .build()

                val trackSelector = DefaultTrackSelector(context)
                val renderersFactory = DefaultRenderersFactory(context)
                    .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_OFF)

                val player = ExoPlayer.Builder(context)
                    .setLoadControl(loadControl)
                    .setMediaSourceFactory(mediaSourceFactory)
                    .setTrackSelector(trackSelector)
                    .setRenderersFactory(renderersFactory)
                    .setHandleAudioBecomingNoisy(true)
                    .setLivePlaybackSpeedControl(
                        DefaultLivePlaybackSpeedControl.Builder()
                            // Takilma sonrasi hedefi biraz geriye alip tampon guvenligi olustur.
                            // Media3 varsayilani 500ms; eski 5000ms gecikmeyi asiri buyutup
                            // oynatmayi canli pencerenin gerisine itiyordu. 0 yapmak ise bu
                            // guvenlik valfini tamamen kapatip tekrarli takilmaya davetiye
                            // cikariyordu. Dengeli deger: 1000ms.
                            .setTargetLiveOffsetIncrementOnRebufferMs(1000)
                            .build()
                    )
                    .build()

                // Ses odagina sahip cik — hizli zap'ta eski/yeni player sesleri
                // birbirine karismasin (sistem duzeyinde garanti)
                player.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(C.USAGE_MEDIA)
                        .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                        .build(),
                    true // handleAudioFocus
                )

                // Surface — needsSurface pattern (video_player_android ile aynı)
                val surface = surfaceProducer.surface
                player.setVideoSurface(surface)

                val instance = PlayerInstance(player, surfaceProducer, textureId, methodChannel)
                players[textureId] = instance

                // Hem textureId (MethodChannel için) hem producerId (Texture widget için) dön
                val producerId = surfaceProducer.id()
                result.success(mapOf("textureId" to textureId, "producerId" to producerId))
            } catch (e: Exception) {
                result.error("CREATE_FAILED", e.message, null)
            }
        }
    }

    private fun open(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId")
            ?: return result.error("MISSING", "textureId", null)
        val url = call.argument<String>("url")
            ?: return result.error("MISSING", "url", null)

        mainHandler.post {
            val instance = players[textureId]
                ?: return@post result.error("NOT_FOUND", "Player bulunamadi", null)
            try {
                val player = instance.player

                // Eski listener'ı kaldır
                player.removeListener(instance.listener)

                // Surface hazır mı kontrol et
                if (instance.needsSurface) {
                    val s = instance.surfaceProducer.surface
                    player.setVideoSurface(s)
                    instance.needsSurface = (s == null)
                }

                // Medya item — canlı yayın için liveConfiguration ekle
                val mediaItem = MediaItem.Builder()
                    .setUri(Uri.parse(url))
                    .setLiveConfiguration(
                        MediaItem.LiveConfiguration.Builder()
                            .setMaxPlaybackSpeed(1.03f)
                            .build()
                    )
                    .build()

                player.setMediaItem(mediaItem)
                player.prepare()
                player.playWhenReady = true
                player.addListener(instance.listener)

                result.success(true)
            } catch (e: Exception) {
                result.error("OPEN_FAILED", e.message, null)
            }
        }
    }

    private fun play(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId") ?: return result.error("MISSING", "textureId", null)
        mainHandler.post { players[textureId]?.player?.play(); result.success(true) }
    }

    private fun pause(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId") ?: return result.error("MISSING", "textureId", null)
        mainHandler.post { players[textureId]?.player?.pause(); result.success(true) }
    }

    private fun stop(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId") ?: return result.error("MISSING", "textureId", null)
        mainHandler.post { try { players[textureId]?.player?.stop() } catch (_: Exception) {}; result.success(true) }
    }

    private fun seek(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId") ?: return result.error("MISSING", "textureId", null)
        val pos = call.argument<Long>("positionMs") ?: 0L
        mainHandler.post { players[textureId]?.player?.seekTo(pos); result.success(true) }
    }

    private fun setVolume(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId") ?: return result.error("MISSING", "textureId", null)
        val vol = call.argument<Double>("volume") ?: 1.0
        mainHandler.post { players[textureId]?.player?.volume = vol.toFloat(); result.success(true) }
    }

    private fun dispose(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId") ?: return result.error("MISSING", "textureId", null)
        mainHandler.post {
            val instance = players.remove(textureId) ?: return@post result.success(true)
            try { instance.player.removeListener(instance.listener); instance.player.stop(); instance.player.release() } catch (_: Exception) {}
            try { instance.surfaceProducer.release() } catch (_: Exception) {}
            result.success(true)
        }
    }

    private fun getPosition(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId") ?: return result.error("MISSING", "textureId", null)
        mainHandler.post { result.success(players[textureId]?.player?.currentPosition ?: 0L) }
    }    private fun getDuration(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId")
            ?: return result.error("MISSING", "textureId", null)
        mainHandler.post { result.success(players[textureId]?.player?.duration ?: C.TIME_UNSET) }
    }

    /// Yayin sagligi icin anlik metrikler: tampon, canli kenar mesafesi,
    /// yeniden baglanma sayisi. Arayuzdeki kalici gosterge bunlari okur.
    private fun getPlaybackMetrics(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId")
            ?: return result.error("MISSING", "textureId", null)
        mainHandler.post {
            val instance = players[textureId]
                ?: return@post result.error("NOT_FOUND", "Player bulunamadi", null)
            try {
                val player = instance.player
                val position = player.currentPosition
                val buffered = (player.bufferedPosition - position).coerceAtLeast(0L)
                // Canli degilse C.TIME_UNSET (-9.22e18) doner; Dart tarafi negatifi
                // "bilinmiyor" olarak yorumlar.
                val liveOffsetMs = if (player.isCurrentMediaItemLive) {
                    player.currentLiveOffset
                } else {
                    C.TIME_UNSET
                }
                result.success(mapOf(
                    "positionMs" to position,
                    "bufferedMs" to buffered,
                    "liveOffsetMs" to liveOffsetMs,
                    "reconnectCount" to instance.reconnectCount
                ))
            } catch (e: Exception) {
                result.error("METRICS_FAILED", e.message, null)
            }
        }
    }

    @UnstableApi
    class PlayerInstance(
        val player: ExoPlayer,
        val surfaceProducer: TextureRegistry.SurfaceProducer,
        val textureId: Long,
        val methodChannel: MethodChannel
    ) : TextureRegistry.SurfaceProducer.Callback {
        private var retries = 0
        var needsSurface = false
        // Hata sonrasi kurtarma sayisi — disaridan (getPlaybackMetrics) okunur
        var reconnectCount = 0

        init {
            surfaceProducer.setCallback(this)
            val s = surfaceProducer.surface
            player.setVideoSurface(s)
            needsSurface = (s == null)
        }

        override fun onSurfaceAvailable() {
            if (needsSurface) {
                val s = surfaceProducer.surface
                player.setVideoSurface(s)
                needsSurface = (s == null)
            }
        }

        override fun onSurfaceCleanup() {
            player.setVideoSurface(null)
            needsSurface = true
        }

        val listener = object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                when (state) {
                    Player.STATE_READY -> {
                        retries = 0
                        send("onReady", mapOf("duration" to player.duration, "position" to player.currentPosition))
                    }
                    Player.STATE_BUFFERING -> send("onBuffering", emptyMap<String, Any>())
                    Player.STATE_ENDED -> send("onCompleted", emptyMap<String, Any>())
                }
            }
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                send("onPlaying", mapOf("isPlaying" to isPlaying))
            }
            override fun onPlayerError(error: PlaybackException) {
                // BehindLiveWindow → live edge'e don ve devam et (canli yayin icin kritik)
                if (error.errorCode == PlaybackException.ERROR_CODE_BEHIND_LIVE_WINDOW && retries < MAX_RETRIES) {
                    retries++
                    reconnectCount++
                    Handler(Looper.getMainLooper()).postDelayed({
                        try {
                            if (needsSurface) {
                                val s = surfaceProducer.surface
                                player.setVideoSurface(s)
                                needsSurface = (s == null)
                            }
                            player.seekToDefaultPosition()
                            player.prepare()
                            player.play()
                        } catch (_: Exception) {}
                    }, 300L)
                    return
                }
                // Genel hata → kisa backoff ile tekrar baglan. Canli yayinda
                // gercek hata nadirdir; cogu "hata" gecici segment/ag dalgalanmasidir.
                if (retries < MAX_RETRIES) {
                    retries++
                    reconnectCount++
                    val delay = (retries * 400L).coerceAtMost(4000L)
                    Handler(Looper.getMainLooper()).postDelayed({
                        try {
                            if (needsSurface) {
                                val s = surfaceProducer.surface
                                player.setVideoSurface(s)
                                needsSurface = (s == null)
                            }
                            // Live edge'e donerek yeniden bagla — bastan uzun
                            // hazirlik yapip gorunur reload'a yol acmasin
                            player.seekToDefaultPosition()
                            player.prepare()
                            player.playWhenReady = true
                        } catch (_: Exception) {}
                    }, delay)
                } else {
                    send("onError", mapOf("message" to (error.message ?: "Hata")))
                }
            }
            override fun onTracksChanged(tracks: Tracks) {
                send("onTracksChanged", mapOf(
                    "audio" to tracks.groups.count { it.type == C.TRACK_TYPE_AUDIO },
                    "subtitle" to tracks.groups.count { it.type == C.TRACK_TYPE_TEXT }
                ))
            }
        }

        private fun send(method: String, args: Map<String, Any>) {
            Handler(Looper.getMainLooper()).post {
                try { methodChannel.invokeMethod(method, mapOf("textureId" to textureId) + args) } catch (_: Exception) {}
            }
        }
    }

    // ═══════════════════════════════════════════════════════
    //  Ses/Altyazi Track Destegi
    // ═══════════════════════════════════════════════════════

    private fun getAudioTracks(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId")
            ?: return result.error("MISSING", "textureId", null)
        val instance = players[textureId]
            ?: return result.error("NOT_FOUND", "Player bulunamadi", null)
        val player = instance.player
        val tracks = mutableListOf<Map<String, Any>>()
        var seqIndex = 0
        for (i in 0 until player.currentTracks.groups.size) {
            val group = player.currentTracks.groups[i]
            if (group.type == C.TRACK_TYPE_AUDIO) {
                for (j in 0 until group.length) {
                    val fmt = group.getTrackFormat(j)
                    tracks.add(mapOf(
                        "id" to "audio_$seqIndex",
                        "label" to (fmt.label ?: fmt.language ?: "Ses ${seqIndex + 1}"),
                        "language" to (fmt.language ?: ""),
                        "group" to i,
                        "item" to j
                    ))
                    seqIndex++
                }
            }
        }
        result.success(tracks)
    }

    private fun getSubtitleTracks(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId")
            ?: return result.error("MISSING", "textureId", null)
        val instance = players[textureId]
            ?: return result.error("NOT_FOUND", "Player bulunamadi", null)
        val player = instance.player
        val tracks = mutableListOf<Map<String, Any>>()
        var seqIndex = 0
        for (i in 0 until player.currentTracks.groups.size) {
            val group = player.currentTracks.groups[i]
            if (group.type == C.TRACK_TYPE_TEXT) {
                for (j in 0 until group.length) {
                    val fmt = group.getTrackFormat(j)
                    tracks.add(mapOf(
                        "id" to "subtitle_$seqIndex",
                        "label" to (fmt.label ?: fmt.language ?: "Altyazi ${seqIndex + 1}"),
                        "language" to (fmt.language ?: ""),
                        "group" to i,
                        "item" to j
                    ))
                    seqIndex++
                }
            }
        }
        result.success(tracks)
    }

    private fun selectAudioTrack(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId")
            ?: return result.error("MISSING", "textureId", null)
        val trackIndex = call.argument<Int>("trackIndex") ?: return result.error("MISSING", "trackIndex", null)
        val instance = players[textureId]
            ?: return result.error("NOT_FOUND", "Player bulunamadi", null)
        val player = instance.player
        var count = 0
        for (i in 0 until player.currentTracks.groups.size) {
            val group = player.currentTracks.groups[i]
            if (group.type == C.TRACK_TYPE_AUDIO) {
                for (j in 0 until group.length) {
                    if (count == trackIndex) {
                        val builder = player.trackSelectionParameters.buildUpon()
                        builder.setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, listOf(j)))
                        player.trackSelectionParameters = builder.build()
                        result.success(true)
                        return
                    }
                    count++
                }
            }
        }
        result.error("NOT_FOUND", "Track bulunamadi", null)
    }

    private fun selectSubtitleTrack(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId")
            ?: return result.error("MISSING", "textureId", null)
        val trackIndex = call.argument<Int>("trackIndex") ?: return result.error("MISSING", "trackIndex", null)
        val instance = players[textureId]
            ?: return result.error("NOT_FOUND", "Player bulunamadi", null)
        val player = instance.player
        if (trackIndex < 0) {
            val builder = player.trackSelectionParameters.buildUpon()
            builder.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
            player.trackSelectionParameters = builder.build()
            result.success(true)
            return
        }
        var count = 0
        for (i in 0 until player.currentTracks.groups.size) {
            val group = player.currentTracks.groups[i]
            if (group.type == C.TRACK_TYPE_TEXT) {
                for (j in 0 until group.length) {
                    if (count == trackIndex) {
                        val builder = player.trackSelectionParameters.buildUpon()
                        builder.setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, listOf(j)))
                        builder.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
                        player.trackSelectionParameters = builder.build()
                        result.success(true)
                        return
                    }
                    count++
                }
            }
        }
        result.error("NOT_FOUND", "Track bulunamadi", null)
    }
}
