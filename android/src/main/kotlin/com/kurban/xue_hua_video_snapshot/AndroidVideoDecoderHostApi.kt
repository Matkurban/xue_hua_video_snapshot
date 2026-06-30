package com.kurban.xue_hua_video_snapshot

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong

/// Android implementation of [VideoDecoderHostApi] using [MediaMetadataRetriever].
class AndroidVideoDecoderHostApi(
    private val appContext: android.content.Context?,
) : VideoDecoderHostApi {

    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val nextSessionId = AtomicLong(1)
    private val sessions = ConcurrentHashMap<Long, RetrieverSession>()

    private data class RetrieverSession(
        val retriever: MediaMetadataRetriever,
        val lock: Any = Any(),
    )

    override fun openSession(url: String, callback: (Result<Long>) -> Unit) {
        worker.execute {
            val result = runCatching {
                val retriever = MediaMetadataRetriever()
                setDataSourceForUrl(retriever, url, appContext)
                val id = nextSessionId.getAndIncrement()
                sessions[id] = RetrieverSession(retriever)
                id
            }
            mainHandler.post { callback(result) }
        }
    }

    override fun probeDuration(sessionId: Long, callback: (Result<Long>) -> Unit) {
        worker.execute {
            val result = runCatching {
                val session = sessions[sessionId]
                    ?: throw FlutterError("SESSION_ERROR", "Unknown session $sessionId", null)
                synchronized(session.lock) {
                    session.retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                        ?.toLongOrNull() ?: 0L
                }
            }
            mainHandler.post { callback(result) }
        }
    }

    override fun captureFrame(
        sessionId: Long,
        positionMs: Long,
        outputPath: String?,
        callback: (Result<CaptureFrameResult>) -> Unit,
    ) {
        worker.execute {
            val result = runCatching {
                val session = sessions[sessionId]
                    ?: throw FlutterError("SESSION_ERROR", "Unknown session $sessionId", null)
                synchronized(session.lock) {
                    val bmp = session.retriever.getFrameAtTime(
                        positionMs * 1000L,
                        MediaMetadataRetriever.OPTION_CLOSEST,
                    ) ?: throw FlutterError("DECODE_FAILED", "No frame at $positionMs", null)
                    try {
                        val rgba = bitmapToRgba64(bmp)
                        var pngPath: String? = null
                        if (outputPath != null) {
                            val outFile = File(outputPath)
                            outFile.parentFile?.mkdirs()
                            FileOutputStream(outFile).use { fos ->
                                bmp.compress(Bitmap.CompressFormat.PNG, 100, fos)
                            }
                            pngPath = outFile.absolutePath
                        }
                        CaptureFrameResult(rgba64 = rgba, pngPath = pngPath)
                    } finally {
                        bmp.recycle()
                    }
                }
            }
            mainHandler.post { callback(result) }
        }
    }

    override fun closeSession(sessionId: Long, callback: (Result<Unit>) -> Unit) {
        worker.execute {
            val result = runCatching {
                val session = sessions.remove(sessionId) ?: return@runCatching
                synchronized(session.lock) {
                    session.retriever.release()
                }
            }
            mainHandler.post { callback(result) }
        }
    }

    private fun setDataSourceForUrl(
        retriever: MediaMetadataRetriever,
        url: String,
        appContext: android.content.Context?,
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

    private fun bitmapToRgba64(bitmap: Bitmap): ByteArray {
        val w = 64
        val h = 64
        val scaled = Bitmap.createScaledBitmap(bitmap, w, h, false)
        val pixels = IntArray(w * h)
        scaled.getPixels(pixels, 0, w, 0, 0, w, h)
        val rgba = ByteArray(w * h * 4)
        for (i in pixels.indices) {
            val p = pixels[i]
            rgba[i * 4] = ((p shr 16) and 0xff).toByte()
            rgba[i * 4 + 1] = ((p shr 8) and 0xff).toByte()
            rgba[i * 4 + 2] = (p and 0xff).toByte()
            rgba[i * 4 + 3] = 255.toByte()
        }
        if (scaled != bitmap) scaled.recycle()
        return rgba
    }
}
