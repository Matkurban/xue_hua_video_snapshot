package com.kurban.xue_hua_video_snapshot

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong

/// Plugin-scoped session registry — survives host API re-instantiation on engine reattach.
object DecoderSessionRegistry {
    private val nextSessionId = AtomicLong(1)
    private val sessions = ConcurrentHashMap<Long, RetrieverSession>()

    data class RetrieverSession(
        val retriever: MediaMetadataRetriever,
        val lock: Any = Any(),
    )

    fun open(retriever: MediaMetadataRetriever): Long {
        val id = nextSessionId.getAndIncrement()
        sessions[id] = RetrieverSession(retriever)
        return id
    }

    fun session(sessionId: Long): RetrieverSession? = sessions[sessionId]

    fun close(sessionId: Long): RetrieverSession? = sessions.remove(sessionId)

    val activeCount: Int get() = sessions.size
}

/// Android implementation of [VideoDecoderHostApi] using [MediaMetadataRetriever].
class AndroidVideoDecoderHostApi(
    private val appContext: android.content.Context?,
) : VideoDecoderHostApi {

    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    override fun openSession(url: String, callback: (Result<Long>) -> Unit) {
        worker.execute {
            val result = runCatching {
                val retriever = MediaMetadataRetriever()
                setDataSourceForUrl(retriever, url, appContext)
                DecoderSessionRegistry.open(retriever)
            }
            mainHandler.post { callback(result) }
        }
    }

    override fun probeDuration(sessionId: Long, callback: (Result<Long>) -> Unit) {
        worker.execute {
            val result = runCatching {
                val session = DecoderSessionRegistry.session(sessionId)
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
                val session = DecoderSessionRegistry.session(sessionId)
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
                val session = DecoderSessionRegistry.close(sessionId) ?: return@runCatching
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
