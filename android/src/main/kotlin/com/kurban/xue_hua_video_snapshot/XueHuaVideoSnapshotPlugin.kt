package com.kurban.xue_hua_video_snapshot

import io.flutter.embedding.engine.plugins.FlutterPlugin

/// Registers the Pigeon [VideoDecoderHostApi] for Android.
class XueHuaVideoSnapshotPlugin : FlutterPlugin {

    private var decoderApi: AndroidVideoDecoderHostApi? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (decoderApi == null) {
            decoderApi = AndroidVideoDecoderHostApi(binding.applicationContext)
        }
        VideoDecoderHostApi.setUp(binding.binaryMessenger, decoderApi)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        VideoDecoderHostApi.setUp(binding.binaryMessenger, null)
        decoderApi = null
    }
}
