import 'package:path_provider/path_provider.dart';

import 'cover_extraction.dart';
import 'video_source.dart';
import 'video_cover_frame.dart';

/// 插件主入口，负责从视频中抽取封面候选帧。
/// Plugin main entry point for extracting cover candidate frames from video.
class XueHuaVideoSnapshot {
  XueHuaVideoSnapshot._({CoverExtraction? extraction})
      : _extraction = extraction ?? CoverExtraction();

  static final XueHuaVideoSnapshot _instance = XueHuaVideoSnapshot._();

  static XueHuaVideoSnapshot get instance => _instance;

  final CoverExtraction _extraction;

  /// 从任意来源的视频中抽取若干非黑的封面候选帧。
  ///
  /// Throws [SnapshotException] when duration probing or decoding fails.
  /// Returns an empty list when decoding succeeds but no frame passes
  /// [minBrightness].
  Future<List<VideoCoverFrame>> extractCoverCandidates(
    VideoSource source, {
    int count = 5,
    double minBrightness = 0.08,
    String? outputDir,
  }) async {
    assert(count > 0, 'count must be > 0');
    final resolved = await source.resolveToNativeUrl();
    final dir = outputDir ?? await _defaultCoverDir();
    return _extraction.extract(
      url: resolved,
      count: count,
      minBrightness: minBrightness,
      outputDir: dir,
    );
  }

  static Future<String> _defaultCoverDir() async {
    final base = await getTemporaryDirectory();
    return '${base.path}/xue_hua_video_snapshot/covers';
  }
}
