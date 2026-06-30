import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/pigeon/video_decoder_api.g.dart',
    dartOptions: DartOptions(),
    dartPackageName: 'xue_hua_video_snapshot',
    kotlinOut:
        'android/src/main/kotlin/com/kurban/xue_hua_video_snapshot/VideoDecoderApi.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.kurban.xue_hua_video_snapshot',
    ),
    swiftOut: 'shared/apple/VideoDecoderApi.swift',
    swiftOptions: SwiftOptions(),
    cppHeaderOut: 'shared/cpp/video_decoder_api.h',
    cppSourceOut: 'shared/cpp/video_decoder_api.cpp',
    cppOptions: CppOptions(namespace: 'xue_hua_video_snapshot'),
  ),
)
class CaptureFrameResult {
  CaptureFrameResult({required this.rgba64, this.pngPath});

  /// 64×64 RGBA pixels (16384 bytes).
  Uint8List rgba64;

  /// Absolute path when [outputPath] was provided and write succeeded.
  String? pngPath;
}

/// Native decode adapter: holds a decoder session open across probe + captures.
@HostApi()
abstract class VideoDecoderHostApi {
  @async
  int openSession(String url);

  @async
  int probeDuration(int sessionId);

  @async
  CaptureFrameResult captureFrame(
    int sessionId,
    int positionMs,
    String? outputPath,
  );

  @async
  void closeSession(int sessionId);
}
