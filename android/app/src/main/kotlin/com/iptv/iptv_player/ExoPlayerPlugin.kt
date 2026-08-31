package com.iptv.iptv_player

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.Surface
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.DefaultLivePlaybackSpeedControl
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import okhttp3.OkHttpClient
import okhttp3.ConnectionSpec
import java.util.Arrays
import java.util.concurrent.TimeUnit

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

                // OkHttp — canavar gibi IPTV bağlantısı
                val okHttpClient = OkHttpClient.Builder()
                    .connectTimeout(30, TimeUnit.SECONDS)
                    .readTimeout(0, TimeUnit.SECONDS)       // Asla timeout yok
                    .writeTimeout(10, TimeUnit.SECONDS)
                    .retryOnConnectionFailure(true)
                    .connectionSpecs(Arrays.asList(
                        ConnectionSpec.MODERN_TLS,
                        ConnectionSpec.CLEARTEXT
                    ))
                    .build()

                val okHttpFactory = OkHttpDataSource.Factory(okHttpClient)
                    .setUserAgent("Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36")

                // Canlı yayın için live target offset — 5sn live edge arkasında
                val mediaSourceFactory = DefaultMediaSourceFactory(okHttpFactory)
                    .setLiveTargetOffsetMs(5000)

                // ULTRA HIZLI ZAPPING — 0.5sn'de oynatmaya başla
                val loadControl = DefaultLoadControl.Builder()
                    .setBufferDurationsMs(
                        5000,    // minBufferMs (5sn)
                        300000,  // maxBufferMs (5 dk)
                        500,     // bufferForPlaybackMs — 0.5sn'de oynat!
                        500      // bufferForPlaybackAfterRebufferMs — 0.5sn'de devam et!
                    )
                    .setBackBuffer(300000, true)
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
                            .setFallbackMinPlaybackSpeed(0.97f)
                            .setFallbackMaxPlaybackSpeed(1.03f)
                            .setTargetLiveOffsetIncrementOnRebufferMs(5000)
                            .setProportionalControlFactor(0.1f)
                            .build()
                    )
                    .build()

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
    }

    private fun getDuration(call: MethodCall, result: MethodChannel.Result) {
        val textureId = call.argument<Long>("textureId") ?: return result.error("MISSING", "textureId", null)
        mainHandler.post { result.success(players[textureId]?.player?.duration ?: C.TIME_UNSET) }
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
                // BehindLiveWindow → otomatik kurtarma (live yayın için kritik)
                if (error.errorCode == PlaybackException.ERROR_CODE_BEHIND_LIVE_WINDOW && retries < 5) {
                    retries++
                    Handler(Looper.getMainLooper()).postDelayed({
                        try {
                            // Surface yeniden ayarla
                            if (needsSurface) {
                                val s = surfaceProducer.surface
                                player.setVideoSurface(s)
                                needsSurface = (s == null)
                            }
                            player.seekToDefaultPosition()
                            player.prepare()
                            player.play()
                        } catch (_: Exception) {}
                    }, 500)
                    return
                }
                // Genel hata → reconnect
                if (retries < 5) {
                    retries++
                    Handler(Looper.getMainLooper()).postDelayed({
                        try {
                            if (needsSurface) {
                                val s = surfaceProducer.surface
                                player.setVideoSurface(s)
                                needsSurface = (s == null)
                            }
                            player.prepare()
                            player.play()
                        } catch (_: Exception) {}
                    }, retries * 2000L)
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
}
