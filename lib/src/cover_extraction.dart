import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';

import 'brightness.dart';
import 'sampling_policy.dart';
import 'video_cover_frame.dart';
import 'video_decoder_port.dart';

/// Deep module: sampling policy, brightness filter, sort, and trim.
class CoverExtraction {
  CoverExtraction({VideoDecoderPort? decoder, this.maxConcurrency = 4})
    : _decoder = decoder ?? PigeonVideoDecoderPort();

  final VideoDecoderPort _decoder;
  final int maxConcurrency;

  Future<List<VideoCoverFrame>> extract({
    required String url,
    required int count,
    required double minBrightness,
    required String outputDir,
  }) async {
    if (count <= 0) {
      throw const SnapshotException(SnapshotException.invalidArgument, 'count must be > 0');
    }
    final candidateBudget = defaultCandidateBudget(count);
    await Directory(outputDir).create(recursive: true);

    int sessionId;
    try {
      sessionId = await _decoder.openSession(url);
    } on PlatformException catch (e) {
      throw SnapshotException.fromPlatform(e, 'open');
    }

    try {
      final durationMs = await _probeDuration(sessionId);
      if (durationMs <= 0) {
        throw const SnapshotException(
          SnapshotException.probeFailed,
          'Video duration is zero or unknown',
        );
      }

      final positions = samplePositionsMs(
        durationMs: durationMs,
        count: count,
        candidates: candidateBudget,
      );

      final samples = await _captureSamples(
        sessionId: sessionId,
        positions: positions,
        minBrightness: minBrightness,
      );

      if (samples.isEmpty) return const [];

      samples.sort((a, b) => b.brightness.compareTo(a.brightness));
      final winners = samples.take(count).toList();

      return await _writeWinnerPngs(
        sessionId: sessionId,
        url: url,
        outputDir: outputDir,
        winners: winners,
      );
    } finally {
      try {
        await _decoder.closeSession(sessionId);
      } on Object {
        // Best-effort close.
      }
    }
  }

  Future<int> _probeDuration(int sessionId) async {
    try {
      return await _decoder.probeDuration(sessionId);
    } on PlatformException catch (e) {
      throw SnapshotException.fromPlatform(e, 'probe', sessionId: sessionId);
    }
  }

  Future<List<_Sample>> _captureSamples({
    required int sessionId,
    required List<int> positions,
    required double minBrightness,
  }) async {
    final results = <_Sample>[];
    var nextIndex = 0;
    Object? firstError;

    int? takePosition() {
      if (nextIndex >= positions.length) return null;
      return positions[nextIndex++];
    }

    Future<void> worker() async {
      while (true) {
        final positionMs = takePosition();
        if (positionMs == null) break;
        try {
          final rgba = await _captureRgba(sessionId, positionMs);
          final brightness = rec601AverageLuma(rgba);
          if (brightness < minBrightness) continue;
          results.add(_Sample(positionMs: positionMs, brightness: brightness));
        } on Object catch (e) {
          firstError ??= e;
        }
      }
    }

    await Future.wait(
      List.generate(maxConcurrency.clamp(1, 32), (_) => worker()),
      eagerError: false,
    );
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, StackTrace.current);
    }
    return results;
  }

  Future<Uint8List> _captureRgba(int sessionId, int positionMs) async {
    try {
      final result = await _decoder.captureFrame(sessionId, positionMs, null);
      return result.rgba64;
    } on PlatformException catch (e) {
      throw SnapshotException.fromPlatform(e, 'capture', sessionId: sessionId);
    }
  }

  Future<List<VideoCoverFrame>> _writeWinnerPngs({
    required int sessionId,
    required String url,
    required String outputDir,
    required List<_Sample> winners,
  }) async {
    final frames = <VideoCoverFrame>[];
    for (final sample in winners) {
      final fileName = 'cover-${url.hashCode.abs()}-${sample.positionMs}.png';
      final outputPath = '$outputDir/$fileName';
      try {
        final result = await _decoder.captureFrame(sessionId, sample.positionMs, outputPath);
        final path = result.pngPath ?? outputPath;
        frames.add(
          VideoCoverFrame(
            image: XFile(path, mimeType: 'image/png'),
            position: Duration(milliseconds: sample.positionMs),
            brightness: sample.brightness.clamp(0.0, 1.0),
          ),
        );
      } on PlatformException catch (e) {
        throw SnapshotException.fromPlatform(e, 'write', sessionId: sessionId);
      }
    }
    return frames;
  }
}

class _Sample {
  const _Sample({required this.positionMs, required this.brightness});

  final int positionMs;
  final double brightness;
}
