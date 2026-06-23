import AVFoundation
import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 使用 AVAssetImageGenerator 从视频中抽取封面候选帧。
/// Extracts cover candidate frames from video using AVAssetImageGenerator.
enum CoverExtractor {
    /// 从视频 URL 中抽取若干非黑的候选封面帧。
    /// Extract non-black cover candidates from a media URL.
    static func extractCovers(
        url: String,
        count: Int,
        candidates: Int,
        minBrightness: Double,
        outputDir: String,
        completion: @escaping ([[String: Any]]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let mediaURL = URL(string: url) else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let asset = AVURLAsset(url: mediaURL)
            let durationSeconds = CMTimeGetSeconds(asset.duration)
            guard durationSeconds.isFinite, durationSeconds > 0 else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let fm = FileManager.default
            try? fm.createDirectory(
                atPath: outputDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = CMTime(
                seconds: 0.5,
                preferredTimescale: 600
            )
            generator.requestedTimeToleranceAfter = CMTime(
                seconds: 0.5,
                preferredTimescale: 600
            )
            generator.maximumSize = CGSize(width: 1280, height: 720)

            // Sample times: skip first/last 5%, evenly distribute `candidates` in between.
            let lower = durationSeconds * 0.05
            let upper = durationSeconds * 0.95
            let span = max(upper - lower, 0.1)
            let n = max(candidates, count)
            var times: [NSValue] = []
            for i in 0..<n {
                let t = lower + span * (Double(i) + 0.5) / Double(n)
                times.append(
                    NSValue(time: CMTime(seconds: t, preferredTimescale: 600))
                )
            }

            var frames: [[String: Any]] = []
            let group = DispatchGroup()
            let sync = DispatchQueue(label: "xue_hua_video_snapshot.covers")
            for value in times {
                _ = value
                group.enter()
            }

            generator.generateCGImagesAsynchronously(forTimes: times) {
                requestedTime,
                cgImage,
                _,
                status,
                _ in
                defer { group.leave() }
                guard status == .succeeded, let cg = cgImage else { return }
                let brightness = Self.averageBrightness(cgImage: cg)
                if brightness < minBrightness { return }
                let ms = Int(CMTimeGetSeconds(requestedTime) * 1000)
                let name = "cover-\(abs(url.hashValue))-\(ms).png"
                let outPath = (outputDir as NSString).appendingPathComponent(
                    name
                )
                if Self.writePNG(cgImage: cg, to: outPath) {
                    sync.sync {
                        frames.append([
                            "path": outPath,
                            "positionMs": ms,
                            "brightness": brightness,
                        ])
                    }
                }
            }

            group.notify(queue: .main) {
                // Sort by brightness descending and trim to count.
                let sorted = frames.sorted { a, b -> Bool in
                    let ab = (a["brightness"] as? Double) ?? 0
                    let bb = (b["brightness"] as? Double) ?? 0
                    return ab > bb
                }
                let trimmed = Array(sorted.prefix(count))
                completion(trimmed)
            }
        }
    }

    // MARK: - Image helpers

    private static func writePNG(cgImage: CGImage, to path: String) -> Bool {
        #if canImport(UIKit)
            guard let data = UIImage(cgImage: cgImage).pngData() else {
                return false
            }
            return (try? data.write(to: URL(fileURLWithPath: path))) != nil
        #elseif canImport(AppKit)
            let rep = NSBitmapImageRep(cgImage: cgImage)
            guard let data = rep.representation(using: .png, properties: [:]) else {
                return false
            }
            return (try? data.write(to: URL(fileURLWithPath: path))) != nil
        #else
            return false
        #endif
    }

    private static func averageBrightness(cgImage: CGImage) -> Double {
        let w = 64
        let h = 64
        let bytesPerRow = w * 4
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard
            let ctx = CGContext(
                data: &data,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        else { return 0 }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        var total: Double = 0
        let pixelCount = w * h
        for i in 0..<pixelCount {
            let r = Double(data[i * 4]) / 255.0
            let g = Double(data[i * 4 + 1]) / 255.0
            let b = Double(data[i * 4 + 2]) / 255.0
            total += 0.299 * r + 0.587 * g + 0.114 * b
        }
        return total / Double(pixelCount)
    }
}
