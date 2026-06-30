import 'package:flutter/services.dart';

import 'pigeon/video_decoder_api.g.dart';

/// Decode adapter seam used by [CoverExtraction].
abstract class VideoDecoderPort {
  Future<int> openSession(String url);
  Future<int> probeDuration(int sessionId);
  Future<CaptureFrameResult> captureFrame(int sessionId, int positionMs, String? outputPath);
  Future<void> closeSession(int sessionId);
}

/// Pigeon-backed [VideoDecoderPort].
class PigeonVideoDecoderPort implements VideoDecoderPort {
  PigeonVideoDecoderPort([VideoDecoderHostApi? api]) : _api = api ?? VideoDecoderHostApi();

  final VideoDecoderHostApi _api;

  @override
  Future<int> openSession(String url) => _api.openSession(url);

  @override
  Future<int> probeDuration(int sessionId) => _api.probeDuration(sessionId);

  @override
  Future<CaptureFrameResult> captureFrame(int sessionId, int positionMs, String? outputPath) =>
      _api.captureFrame(sessionId, positionMs, outputPath);

  @override
  Future<void> closeSession(int sessionId) => _api.closeSession(sessionId);
}

/// Thrown when cover extraction fails due to probe or decode errors.
class SnapshotException implements Exception {
  const SnapshotException(this.code, this.message, {this.phase, this.sessionId});

  final String code;
  final String message;

  /// Native call phase: `open`, `probe`, `capture`, or `write`.
  final String? phase;

  /// Decoder session id when the failure occurred after [open].
  final int? sessionId;

  static const String probeFailed = 'PROBE_FAILED';
  static const String decodeFailed = 'DECODE_FAILED';
  static const String invalidArgument = 'INVALID_ARGUMENT';
  static const String sessionError = 'SESSION_ERROR';

  factory SnapshotException.fromPlatform(PlatformException e, String phase, {int? sessionId}) {
    final code = e.code.isNotEmpty ? e.code : decodeFailed;
    final detail = e.message ?? 'Native $phase failed';
    return SnapshotException(code, detail, phase: phase, sessionId: sessionId);
  }

  @override
  String toString() {
    final buf = StringBuffer('SnapshotException($code');
    if (phase != null) buf.write(', phase=$phase');
    if (sessionId != null) buf.write(', sessionId=$sessionId');
    buf.write('): $message');
    return buf.toString();
  }
}
