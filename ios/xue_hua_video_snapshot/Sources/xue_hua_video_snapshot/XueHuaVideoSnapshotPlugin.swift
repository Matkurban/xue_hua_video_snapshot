import Flutter
import Foundation

/// iOS plugin entry — registers Pigeon [VideoDecoderHostApi].
public class XueHuaVideoSnapshotPlugin: NSObject, FlutterPlugin {
    private let decoderApi = AppleVideoDecoderHostApi()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = XueHuaVideoSnapshotPlugin()
        VideoDecoderHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance.decoderApi)
        registrar.addMethodCallDelegate(instance, channel: FlutterMethodChannel(
            name: "xue_hua_video_snapshot",
            binaryMessenger: registrar.messenger()
        ))
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(FlutterMethodNotImplemented)
    }
}
