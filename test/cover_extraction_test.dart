import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_video_snapshot/src/brightness.dart';
import 'package:xue_hua_video_snapshot/src/cover_extraction.dart';
import 'package:xue_hua_video_snapshot/src/pigeon/video_decoder_api.g.dart';
import 'package:xue_hua_video_snapshot/src/sampling_policy.dart';
import 'package:xue_hua_video_snapshot/src/video_decoder_port.dart';

void main() {
  group('rec601AverageLuma', () {
    test('white pixel averages to 1.0', () {
      final rgba = Uint8List(64 * 64 * 4);
      for (var i = 0; i < 64 * 64; i++) {
        rgba[i * 4] = 255;
        rgba[i * 4 + 1] = 255;
        rgba[i * 4 + 2] = 255;
        rgba[i * 4 + 3] = 255;
      }
      expect(rec601AverageLuma(rgba), closeTo(1.0, 0.001));
    });

    test('black pixel averages to 0.0', () {
      final rgba = Uint8List(64 * 64 * 4);
      expect(rec601AverageLuma(rgba), 0.0);
    });
  });

  group('samplePositionsMs', () {
    test('samples between 5% and 95%', () {
      final positions = samplePositionsMs(durationMs: 10_000, count: 5, candidates: 15);
      expect(positions, isNotEmpty);
      expect(positions.first, greaterThanOrEqualTo(500));
      expect(positions.last, lessThanOrEqualTo(9500));
      expect(positions.length, 15);
    });
  });

  group('CoverExtraction', () {
    test('returns empty when all frames are dark', () async {
      final decoder = _FakeDecoder(durationMs: 10_000, rgbaBuilder: (_) => Uint8List(64 * 64 * 4));
      final extraction = CoverExtraction(decoder: decoder, maxConcurrency: 2);
      final frames = await extraction.extract(
        url: 'file:///tmp/video.mp4',
        count: 3,
        minBrightness: 0.08,
        outputDir: '/tmp/out',
      );
      expect(frames, isEmpty);
      expect(decoder.closed, isTrue);
    });

    test('returns brightest frames sorted descending', () async {
      final decoder = _FakeDecoder(
        durationMs: 10_000,
        rgbaBuilder: (positionMs) {
          final rgba = Uint8List(64 * 64 * 4);
          final level = (positionMs ~/ 1000).clamp(0, 255);
          for (var i = 0; i < 64 * 64; i++) {
            rgba[i * 4] = level;
            rgba[i * 4 + 1] = level;
            rgba[i * 4 + 2] = level;
            rgba[i * 4 + 3] = 255;
          }
          return rgba;
        },
      );
      final extraction = CoverExtraction(decoder: decoder, maxConcurrency: 2);
      final frames = await extraction.extract(
        url: 'file:///tmp/video.mp4',
        count: 2,
        minBrightness: 0.01,
        outputDir: '/tmp/out',
      );
      expect(frames.length, 2);
      expect(frames[0].brightness, greaterThanOrEqualTo(frames[1].brightness));
    });

    test('throws when probe returns zero duration', () async {
      final decoder = _FakeDecoder(durationMs: 0);
      final extraction = CoverExtraction(decoder: decoder);
      await expectLater(
        extraction.extract(
          url: 'file:///tmp/video.mp4',
          count: 1,
          minBrightness: 0.08,
          outputDir: '/tmp/out',
        ),
        throwsA(
          isA<SnapshotException>().having((e) => e.code, 'code', SnapshotException.probeFailed),
        ),
      );
    });

    test('closes session after all workers finish when one capture fails', () async {
      final decoder = _SlowFailDecoder(durationMs: 10_000);
      final extraction = CoverExtraction(decoder: decoder, maxConcurrency: 2);
      await expectLater(
        extraction.extract(
          url: 'file:///tmp/video.mp4',
          count: 2,
          minBrightness: 0.01,
          outputDir: '/tmp/out',
        ),
        throwsA(isA<SnapshotException>()),
      );
      expect(decoder.inFlightAtClose, 0);
      expect(decoder.closed, isTrue);
    });

    test('writes PNGs before closing session', () async {
      final decoder = _SessionOrderDecoder(durationMs: 10_000);
      final extraction = CoverExtraction(decoder: decoder, maxConcurrency: 2);
      final frames = await extraction.extract(
        url: 'file:///tmp/video.mp4',
        count: 1,
        minBrightness: 0.01,
        outputDir: '/tmp/out',
      );
      expect(frames, hasLength(1));
      expect(decoder.writeCaptureAfterClose, isFalse);
      expect(decoder.closed, isTrue);
    });

    test('throws when count is zero', () async {
      final decoder = _FakeDecoder(durationMs: 10_000);
      final extraction = CoverExtraction(decoder: decoder);
      await expectLater(
        extraction.extract(
          url: 'file:///tmp/video.mp4',
          count: 0,
          minBrightness: 0.08,
          outputDir: '/tmp/out',
        ),
        throwsA(
          isA<SnapshotException>().having((e) => e.code, 'code', SnapshotException.invalidArgument),
        ),
      );
      expect(decoder.closed, isFalse);
    });
  });
}

class _FakeDecoder implements VideoDecoderPort {
  _FakeDecoder({required this.durationMs, this.rgbaBuilder});

  final int durationMs;
  final Uint8List Function(int positionMs)? rgbaBuilder;
  bool closed = false;
  var _nextSession = 1;

  @override
  Future<int> openSession(String url) async => _nextSession++;

  @override
  Future<int> probeDuration(int sessionId) async => durationMs;

  @override
  Future<CaptureFrameResult> captureFrame(int sessionId, int positionMs, String? outputPath) async {
    final rgba = rgbaBuilder?.call(positionMs) ?? Uint8List(64 * 64 * 4);
    return CaptureFrameResult(rgba64: rgba, pngPath: outputPath);
  }

  @override
  Future<void> closeSession(int sessionId) async {
    closed = true;
  }
}

class _SessionOrderDecoder implements VideoDecoderPort {
  _SessionOrderDecoder({required this.durationMs});

  final int durationMs;
  bool closed = false;
  bool writeCaptureAfterClose = false;
  var _nextSession = 1;

  @override
  Future<int> openSession(String url) async => _nextSession++;

  @override
  Future<int> probeDuration(int sessionId) async => durationMs;

  @override
  Future<CaptureFrameResult> captureFrame(int sessionId, int positionMs, String? outputPath) async {
    if (outputPath != null && closed) {
      writeCaptureAfterClose = true;
      throw PlatformException(code: 'SESSION_ERROR', message: 'Unknown session');
    }
    final rgba = Uint8List(64 * 64 * 4);
    for (var i = 0; i < 64 * 64; i++) {
      rgba[i * 4] = 200;
      rgba[i * 4 + 1] = 200;
      rgba[i * 4 + 2] = 200;
      rgba[i * 4 + 3] = 255;
    }
    return CaptureFrameResult(rgba64: rgba, pngPath: outputPath);
  }

  @override
  Future<void> closeSession(int sessionId) async {
    closed = true;
  }
}

class _SlowFailDecoder implements VideoDecoderPort {
  _SlowFailDecoder({required this.durationMs});

  final int durationMs;
  var inFlightAtClose = 0;
  bool closed = false;
  var _nextSession = 1;
  var _captureCalls = 0;

  @override
  Future<int> openSession(String url) async => _nextSession++;

  @override
  Future<int> probeDuration(int sessionId) async => durationMs;

  @override
  Future<CaptureFrameResult> captureFrame(int sessionId, int positionMs, String? outputPath) async {
    final callId = ++_captureCalls;
    inFlightAtClose++;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      if (callId == 2) {
        throw const SnapshotException(SnapshotException.decodeFailed, 'simulated decode failure');
      }
      final rgba = Uint8List(64 * 64 * 4);
      for (var i = 0; i < 64 * 64; i++) {
        rgba[i * 4] = 200;
        rgba[i * 4 + 1] = 200;
        rgba[i * 4 + 2] = 200;
        rgba[i * 4 + 3] = 255;
      }
      return CaptureFrameResult(rgba64: rgba, pngPath: outputPath);
    } finally {
      inFlightAtClose--;
    }
  }

  @override
  Future<void> closeSession(int sessionId) async {
    closed = true;
  }
}
