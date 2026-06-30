import Foundation

/// Coerces Pigeon message arguments to [Int64].
///
/// Dart [_PigeonCodec] always writes `int` as StandardMessageCodec type-4 Int64,
/// but Apple codecs may deliver [NSNumber] or [Int].
enum PigeonCodecHelpers {
    static func int64(from value: Any?) -> Int64 {
        switch value {
        case let v as Int64:
            return v
        case let v as Int:
            return Int64(v)
        case let n as NSNumber:
            return n.int64Value
        default:
            fatalError("Expected numeric pigeon argument, got \(String(describing: value))")
        }
    }
}
