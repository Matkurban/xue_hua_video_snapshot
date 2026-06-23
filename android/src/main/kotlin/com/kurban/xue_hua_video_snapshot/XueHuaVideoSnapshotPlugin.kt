package com.kurban.xue_hua_video_snapshot

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import kotlin.math.abs

/// 插件主类，注册 MethodChannel，通过 MediaMetadataRetriever 抽取封面候选帧。
/// Main plugin class registering MethodChannel for cover extraction via MediaMetadataRetriever.
class XueHuaVideoSnapshotPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var methodChannel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())
    private val workerExecutor = Executors.newSingleThreadExecutor()
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding = binding
        methodChannel = MethodChannel(binding.binaryMessenger, "xue_hua_video_snapshot")
        methodChannel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        flutterPluginBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "extractCovers" -> handleExtractCovers(call, result)
            else -> result.notImplemented()
        }
    }

    // region Snapshot / Covers

    /// 抽取视频候选封面帧列表。
    /// Extract cover candidate frames from a media URL.
    private fun handleExtractCovers(call: MethodCall, result: Result) {
        val url = call.argument<String>("url")
        val count = call.argument<Int>("count") ?: 5
        val candidates = call.argument<Int>("candidates") ?: (count * 3)
        val minBrightness = call.argument<Double>("minBrightness") ?: 0.08
        val outputDir = call.argument<String>("outputDir") ?: ""
        val appContext = flutterPluginBinding?.applicationContext
        if (url == null) {
            result.success(emptyList<Any>())
            return
        }
        workerExecutor.execute {
            val frames = ArrayList<Map<String, Any>>()
            val retriever = MediaMetadataRetriever()
            try {
                setDataSourceForUrl(retriever, url, appContext)
                val durMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    ?.toLongOrNull() ?: 0L
                if (durMs <= 0) {
                    mainHandler.post { result.success(emptyList<Any>()) }
                    return@execute
                }
                val dir = File(outputDir.ifEmpty { appContext?.cacheDir?.absolutePath ?: "/tmp" })
                if (!dir.exists()) dir.mkdirs()

                val lower = (durMs * 0.05).toLong()
                val upper = (durMs * 0.95).toLong()
                val span = (upper - lower).coerceAtLeast(1L)
                val n = maxOf(candidates, count)
                for (i in 0 until n) {
                    val t = lower + (span * (i + 0.5) / n).toLong()
                    val bmp = retriever.getFrameAtTime(t * 1000L, MediaMetadataRetriever.OPTION_CLOSEST)
                        ?: continue
                    val brightness = averageBrightness(bmp)
                    if (brightness < minBrightness) {
                        bmp.recycle()
                        continue
                    }
                    val outFile = File(dir, "cover-${abs(url.hashCode())}-$t.png")
                    try {
                        FileOutputStream(outFile).use { fos ->
                            bmp.compress(Bitmap.CompressFormat.PNG, 100, fos)
                        }
                        frames.add(
                            mapOf(
                                "path" to outFile.absolutePath,
                                "positionMs" to t,
                                "brightness" to brightness
                            )
                        )
                    } catch (_: Throwable) {
                        // skip
                    } finally {
                        bmp.recycle()
                    }
                }
                frames.sortByDescending { (it["brightness"] as? Double) ?: 0.0 }
                val trimmed = frames.take(count)
                mainHandler.post { result.success(trimmed) }
            } catch (t: Throwable) {
                mainHandler.post { result.success(emptyList<Any>()) }
            } finally {
                try {
                    retriever.release()
                } catch (_: Throwable) {
                }
            }
        }
    }

    private fun setDataSourceForUrl(
        retriever: MediaMetadataRetriever,
        url: String,
        appContext: android.content.Context?
    ) {
        val uri = Uri.parse(url)
        when (uri.scheme?.lowercase()) {
            "file" -> retriever.setDataSource(uri.path ?: url)
            "http", "https" -> retriever.setDataSource(url, HashMap())
            "content" -> {
                if (appContext != null) retriever.setDataSource(appContext, uri)
                else retriever.setDataSource(url, HashMap())
            }

            else -> retriever.setDataSource(url)
        }
    }

    private fun averageBrightness(bmp: Bitmap): Double {
        val w = 64
        val h = 64
        val scaled = Bitmap.createScaledBitmap(bmp, w, h, false)
        val pixels = IntArray(w * h)
        scaled.getPixels(pixels, 0, w, 0, 0, w, h)
        var total = 0.0
        for (p in pixels) {
            val r = ((p shr 16) and 0xff) / 255.0
            val g = ((p shr 8) and 0xff) / 255.0
            val b = (p and 0xff) / 255.0
            total += 0.299 * r + 0.587 * g + 0.114 * b
        }
        if (scaled != bmp) scaled.recycle()
        return total / pixels.size
    }

    // endregion
}
