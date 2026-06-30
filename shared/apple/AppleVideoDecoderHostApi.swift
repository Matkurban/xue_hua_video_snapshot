import AVFoundation
import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Apple AVFoundation session decoder for [VideoDecoderHostApi].
final class AppleVideoDecoderHostApi: VideoDecoderHostApi {
    private struct Session {
        let asset: AVURLAsset
        let generator: AVAssetImageGenerator
        let lock = NSLock()
    }

    private var sessions: [Int64: Session] = [:]
    private var nextSessionId: Int64 = 1
    private let sessionsLock = NSLock()
    private let workQueue = DispatchQueue(label: "xue_hua_video_snapshot.decoder", qos: .userInitiated)

    func openSession(url: String, completion: @escaping (Result<Int64, Error>) -> Void) {
        workQueue.async {
            let result: Result<Int64, Error> = {
                guard let mediaURL = URL(string: url) else {
                    return .failure(PigeonError(code: "INVALID_ARGUMENT", message: "Invalid url", details: nil))
                }
                let asset = AVURLAsset(url: mediaURL)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
                generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
                generator.maximumSize = CGSize(width: 1280, height: 720)

                self.sessionsLock.lock()
                let id = self.nextSessionId
                self.nextSessionId += 1
                self.sessions[id] = Session(asset: asset, generator: generator)
                self.sessionsLock.unlock()
                return .success(id)
            }()
            DispatchQueue.main.async { completion(result) }
        }
    }

    func probeDuration(sessionId: Int64, completion: @escaping (Result<Int64, Error>) -> Void) {
        workQueue.async {
            let result: Result<Int64, Error> = {
                guard let session = self.session(for: sessionId) else {
                    return .failure(PigeonError(code: "SESSION_ERROR", message: "Unknown session", details: nil))
                }
                session.lock.lock()
                defer { session.lock.unlock() }
                let seconds = CMTimeGetSeconds(session.asset.duration)
                guard seconds.isFinite, seconds > 0 else {
                    return .failure(PigeonError(code: "PROBE_FAILED", message: "Duration unavailable", details: nil))
                }
                return .success(Int64(seconds * 1000.0))
            }()
            DispatchQueue.main.async { completion(result) }
        }
    }

    func captureFrame(
        sessionId: Int64,
        positionMs: Int64,
        outputPath: String?,
        completion: @escaping (Result<CaptureFrameResult, Error>) -> Void
    ) {
        workQueue.async {
            let result: Result<CaptureFrameResult, Error> = {
                guard let session = self.session(for: sessionId) else {
                    return .failure(PigeonError(code: "SESSION_ERROR", message: "Unknown session", details: nil))
                }
                session.lock.lock()
                defer { session.lock.unlock() }

                let time = CMTime(value: positionMs, timescale: 1000)
                var actual = CMTime.zero
                let cgImage: CGImage
                do {
                    cgImage = try session.generator.copyCGImage(at: time, actualTime: &actual)
                } catch {
                    return .failure(PigeonError(code: "DECODE_FAILED", message: error.localizedDescription, details: nil))
                }

                let rgba = Self.rgba64(from: cgImage)
                var pngPath: String? = nil
                if let outputPath {
                    guard Self.writePNG(cgImage: cgImage, to: outputPath) else {
                        return .failure(PigeonError(code: "DECODE_FAILED", message: "PNG write failed", details: nil))
                    }
                    pngPath = outputPath
                }
                return .success(CaptureFrameResult(rgba64: rgba, pngPath: pngPath))
            }()
            DispatchQueue.main.async { completion(result) }
        }
    }

    func closeSession(sessionId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        workQueue.async {
            self.sessionsLock.lock()
            self.sessions.removeValue(forKey: sessionId)
            self.sessionsLock.unlock()
            DispatchQueue.main.async { completion(.success(())) }
        }
    }

    private func session(for id: Int64) -> Session? {
        sessionsLock.lock()
        defer { sessionsLock.unlock() }
        return sessions[id]
    }

    private static func rgba64(from cgImage: CGImage) -> Data {
        let w = 64
        let h = 64
        let bytesPerRow = w * 4
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: &data,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return Data(count: w * h * 4)
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        return Data(data)
    }

    private static func writePNG(cgImage: CGImage, to path: String) -> Bool {
        #if canImport(UIKit)
        guard let data = UIImage(cgImage: cgImage).pngData() else { return false }
        return (try? data.write(to: URL(fileURLWithPath: path))) != nil
        #elseif canImport(AppKit)
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: URL(fileURLWithPath: path))) != nil
        #else
        return false
        #endif
    }
}
