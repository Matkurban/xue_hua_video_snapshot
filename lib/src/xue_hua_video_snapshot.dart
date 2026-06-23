import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'video_source.dart';
import 'video_cover_frame.dart';

/// 插件主入口，负责从视频中抽取封面候选帧。
/// Plugin main entry point for extracting cover candidate frames from video.
class XueHuaVideoSnapshot {
  XueHuaVideoSnapshot._();

  static final XueHuaVideoSnapshot _instance = XueHuaVideoSnapshot._();

  static XueHuaVideoSnapshot get instance => _instance;

  static const MethodChannel _channel = MethodChannel('xue_hua_video_snapshot');

  /// 从任意来源的视频中抽取若干非黑的封面候选帧。
  ///
  /// * [source] 支持 [NetworkVideoSource] / [FileVideoSource] / [AssetVideoSource]。
  ///   asset 在这里会被抽取到临时目录后再交给原生端解码。
  /// * [count] 返回的候选数量上限（按亮度降序排序后截取）。
  /// * [minBrightness] 过滤阈值，低于此值的帧（接近纯黑）会被丢弃。
  /// * [outputDir] 指定 PNG 输出目录；不传则落入应用临时目录。
  ///
  /// 返回按亮度降序排好的候选列表；若原生端解码失败或被过滤完则返回空列表。
  ///
  /// Extract a handful of non-black cover candidates from any [VideoSource].
  /// Results are sorted by brightness descending. Asset sources are extracted
  /// to a temp file before decoding. Returns an empty list on failure.
  Future<List<VideoCoverFrame>> extractCoverCandidates(
    VideoSource source, {
    int count = 5,
    double minBrightness = 0.08,
    String? outputDir,
  }) async {
    assert(count > 0, 'count must be > 0');
    final candidateCount = (count * 3).clamp(count, 30);
    final resolved = await source.resolveToNativeUrl();
    final dir = outputDir ?? await _defaultCoverDir();

    final raw = await _channel.invokeMethod<dynamic>('extractCovers', {
      'url': resolved,
      'count': count,
      'candidates': candidateCount,
      'minBrightness': minBrightness,
      'outputDir': dir,
    });
    if (raw == null) return const <VideoCoverFrame>[];
    final list = (raw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(_frameFromMap)
        .whereType<VideoCoverFrame>()
        .toList();
    list.sort((a, b) => b.brightness.compareTo(a.brightness));
    return list;
  }

  static VideoCoverFrame? _frameFromMap(Map<String, dynamic> map) {
    final path = map['path'] as String?;
    final positionMs = (map['positionMs'] as num?)?.toInt() ?? 0;
    final brightness = (map['brightness'] as num?)?.toDouble() ?? 0.0;
    if (path == null || path.isEmpty) return null;
    return VideoCoverFrame(
      image: XFile(path, mimeType: 'image/png'),
      position: Duration(milliseconds: positionMs),
      brightness: brightness.clamp(0.0, 1.0),
    );
  }

  static Future<String> _defaultCoverDir() async {
    final base = await getTemporaryDirectory();
    return '${base.path}/xue_hua_video_snapshot/covers';
  }
}
