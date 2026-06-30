import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_video_snapshot/src/file_uri.dart';
import 'package:xue_hua_video_snapshot/src/video_source.dart';

void main() {
  group('FileVideoSource', () {
    test('identity matches resolveToNativeUrl for plain path', () async {
      const source = FileVideoSource('/tmp/video.mp4');
      expect(source.identity, await source.resolveToNativeUrl());
    });

    test('identity matches resolveToNativeUrl for file URI', () async {
      const source = FileVideoSource('file:///tmp/video.mp4');
      expect(source.identity, await source.resolveToNativeUrl());
    });
  });

  group('normalizeFileUri', () {
    test('normalizes plain paths', () {
      expect(normalizeFileUri('/tmp/a.mp4'), normalizeFileUri('file:///tmp/a.mp4'));
    });
  });
}
