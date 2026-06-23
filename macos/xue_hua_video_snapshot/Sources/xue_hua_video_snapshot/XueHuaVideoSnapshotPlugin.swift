import FlutterMacOS
import Foundation

/// macOS 插件主类，通过 AVAssetImageGenerator 抽取视频封面候选帧。
/// macOS plugin main class for extracting cover candidates via AVAssetImageGenerator.
public class XueHuaVideoSnapshotPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = XueHuaVideoSnapshotPlugin()
        let methodChannel = FlutterMethodChannel(
            name: "xue_hua_video_snapshot",
            binaryMessenger: registrar.messenger
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
    }

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "extractCovers":
            guard let args = call.arguments as? [String: Any],
                let url = args["url"] as? String
            else {
                result(
                    FlutterError(
                        code: "INVALID_ARG",
                        message: "url is required",
                        details: nil
                    )
                )
                return
            }
            let count = (args["count"] as? Int) ?? 5
            let candidates = (args["candidates"] as? Int) ?? (count * 3)
            let minBrightness = (args["minBrightness"] as? Double) ?? 0.08
            let outputDir =
                (args["outputDir"] as? String) ?? NSTemporaryDirectory()
            CoverExtractor.extractCovers(
                url: url,
                count: count,
                candidates: candidates,
                minBrightness: minBrightness,
                outputDir: outputDir,
                completion: { result($0) }
            )
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
