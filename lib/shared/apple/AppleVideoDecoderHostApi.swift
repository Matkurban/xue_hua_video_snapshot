import AVFoundation
import CoreGraphics
import Foundation
#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Plugin-scoped session registry — survives host API re-instantiation on plugin re-register.
final class DecoderSessionRegistry {
    static let shared = DecoderSessionRegistry()

    struct Session {
        let asset: AVURLAsset
        let generator: AVAssetImageGenerator
        let lock = NSLock()
    }

    private var sessions: [Int64: Session] = [:]
    private var nextSessionId: Int64 = 1
    private let sessionsLock = NSLock()

    private init() {}

    func open(url: URL) -> Int64 {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.maximumSize = CGSize(width: 1280, height: 720)

        sessionsLock.lock()
        let id = nextSessionId
        nextSessionId += 1
        sessions[id] = Session(asset: asset, generator: generator)
        sessionsLock.unlock()
        return id
    }

    func session(for id: Int64) -> Session? {
        sessionsLock.lock()
        defer { sessionsLock.unlock() }
        return sessions[id]
    }

    func close(id: Int64) {
        sessionsLock.lock()
        sessions.removeValue(forKey: id)
        sessionsLock.unlock()
    }

    var activeCount: Int {
        sessionsLock.lock()
        defer { sessionsLock.unlock() }
        return sessions.count
    }
}

/// Apple AVFoundation session decoder for [VideoDecoderHostApi].
final class AppleVideoDecoderHostApi: VideoDecoderHostApi {
    private let registry = DecoderSessionRegistry.shared
    private let workQueue = DispatchQueue(label: "xue_hua_video_snapshot.decoder", qos: .userInitiated)

    func openSession(url: String, completion: @escaping (Result<Int64, Error>) -> Void) {
        workQueue.async {
            let result: Result<Int64, Error> = {
                guard let mediaURL = URL(string: url) else {
                    return .failure(PigeonError(code: "INVALID_ARGUMENT", message: "Invalid url", details: nil))
                }
                let id = self.registry.open(url: mediaURL)
                return .success(id)
            }()
            DispatchQueue.main.async { completion(result) }
        }
    }

    func probeDuration(sessionId: Int64, completion: @escaping (Result<Int64, Error>) -> Void) {
        workQueue.async {
            let result: Result<Int64, Error> = {
                guard let session = self.registry.session(for: sessionId) else {
                    return .failure(PigeonError(code: "SESSION_ERROR", message: "Unknown session", details: nil))
                }
                session.lock.lock()
                defer { session.lock.unlock() }
                let loadError = Self.loadAssetMetadata(session.asset)
                if let loadError {
                    return .failure(loadError)
                }
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
                guard let session = self.registry.session(for: sessionId) else {
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

                let rgba: Data
                do {
                    rgba = try Self.rgba64(from: cgImage)
                } catch let error as PigeonError {
                    return .failure(error)
                } catch {
                    return .failure(PigeonError(code: "DECODE_FAILED", message: error.localizedDescription, details: nil))
                }
                var pngPath: String? = nil
                if let outputPath {
                    guard Self.writePNG(cgImage: cgImage, to: outputPath) else {
                        return .failure(PigeonError(code: "DECODE_FAILED", message: "PNG write failed", details: nil))
                    }
                    pngPath = outputPath
                }
                return .success(
                    CaptureFrameResult(
                        rgba64: FlutterStandardTypedData(bytes: rgba),
                        pngPath: pngPath
                    )
                )
            }()
            DispatchQueue.main.async { completion(result) }
        }
    }

    func closeSession(sessionId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        workQueue.async {
            self.registry.close(id: sessionId)
            DispatchQueue.main.async { completion(.success(())) }
        }
    }

    private static func loadAssetMetadata(_ asset: AVURLAsset) -> PigeonError? {
        let keys = ["duration", "tracks"]
        let group = DispatchGroup()
        group.enter()
        asset.loadValuesAsynchronously(forKeys: keys) {
            group.leave()
        }
        group.wait()

        var nsError: NSError?
        let status = asset.statusOfValue(forKey: "duration", error: &nsError)
        switch status {
        case .loaded:
            return nil
        case .failed:
            let message = nsError?.localizedDescription ?? "Duration load failed"
            return PigeonError(code: "PROBE_FAILED", message: message, details: nil)
        case .cancelled:
            return PigeonError(code: "PROBE_FAILED", message: "Duration load cancelled", details: nil)
        default:
            return PigeonError(code: "PROBE_FAILED", message: "Duration unavailable", details: nil)
        }
    }

    private static func rgba64(from cgImage: CGImage) throws -> Data {
        let w = 64
        let h = 64
        let bytesPerRow = w * 4
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
        guard let ctx = CGContext(
            data: &data,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw PigeonError(code: "DECODE_FAILED", message: "Failed to create RGBA context", details: nil)
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        for i in 0..<(w * h) {
            let o = i * 4 + 3
            data[o] = 255
        }
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
