import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

typedef TempDirectoryResolver = Future<Directory> Function();
typedef DefaultBundleResolver = AssetBundle Function();

/// 负责把 Flutter assets 中的媒体懒抽取到本地文件，供原生解码器使用。
///
/// Injectable [tempDirectory] / [defaultBundle] make this module testable.
/// Use [instance] from production code; replace via [debugReplaceInstance] in tests.
class AssetExtractor {
  AssetExtractor({TempDirectoryResolver? tempDirectory, DefaultBundleResolver? defaultBundle})
    : _tempDirectory = tempDirectory ?? getTemporaryDirectory,
      _defaultBundle = defaultBundle ?? (() => rootBundle);

  static AssetExtractor instance = AssetExtractor();

  @visibleForTesting
  static void debugReplaceInstance(AssetExtractor replacement) {
    instance = replacement;
  }

  @visibleForTesting
  static void debugResetInstance() {
    instance = AssetExtractor();
  }

  final TempDirectoryResolver _tempDirectory;
  final DefaultBundleResolver _defaultBundle;
  final Map<String, Future<String>> _inflight = <String, Future<String>>{};

  /// 返回抽取后落地文件的绝对路径；若已存在则直接复用。
  Future<String> extract(String assetPath, {AssetBundle? bundle}) {
    final resolvedBundle = bundle ?? _defaultBundle();
    final key = _inflightKey(assetPath, resolvedBundle);
    final inflight = _inflight[key];
    if (inflight != null) return inflight;
    final future = _doExtract(assetPath, resolvedBundle);
    _inflight[key] = future;
    future.whenComplete(() => _inflight.remove(key));
    return future;
  }

  @visibleForTesting
  Map<String, Future<String>> get inflightForTesting => _inflight;

  static String inflightKey(String assetPath, AssetBundle bundle) {
    return '$assetPath::${identityHashCode(bundle)}';
  }

  String _inflightKey(String assetPath, AssetBundle bundle) => inflightKey(assetPath, bundle);

  static String cacheFileName(String assetPath, AssetBundle bundle) {
    final digest = sha1.convert('${identityHashCode(bundle)}:$assetPath'.codeUnits);
    final baseName = assetPath.split('/').last;
    final safeName = baseName.isEmpty ? 'media' : baseName;
    return '${digest.toString()}-$safeName';
  }

  Future<String> _doExtract(String assetPath, AssetBundle bundle) async {
    final tempDir = await _tempDirectory();
    final root = Directory('${tempDir.path}/xue_hua_video_snapshot/assets');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    final outPath = '${root.path}/${cacheFileName(assetPath, bundle)}';
    final bytes = await bundle.load(assetPath);
    final expectedLength = bytes.lengthInBytes;
    final file = File(outPath);
    if (await file.exists()) {
      final length = await file.length();
      if (length == expectedLength) {
        return outPath;
      }
      await file.delete();
    }
    final buffer = bytes.buffer.asUint8List(bytes.offsetInBytes, expectedLength);
    final tmpPath = '$outPath.tmp';
    final tmpFile = File(tmpPath);
    if (await tmpFile.exists()) {
      await tmpFile.delete();
    }
    final sink = tmpFile.openWrite();
    try {
      sink.add(buffer);
      await sink.flush();
      await sink.close();
      await tmpFile.rename(outPath);
    } on Object {
      await sink.close();
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
      rethrow;
    }
    return outPath;
  }
}
