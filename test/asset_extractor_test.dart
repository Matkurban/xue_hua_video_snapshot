import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_video_snapshot/src/asset_extractor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _MemoryBundle bundleA;
  late _MemoryBundle bundleB;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xhvs_asset_test_');
    bundleA = _MemoryBundle({
      'assets/a.mp4': Uint8List.fromList([1, 2, 3]),
    });
    bundleB = _MemoryBundle({
      'assets/a.mp4': Uint8List.fromList([9, 9, 9]),
    });
    AssetExtractor.debugReplaceInstance(AssetExtractor(tempDirectory: () async => tempDir));
  });

  tearDown(() async {
    AssetExtractor.debugResetInstance();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('inflight key includes bundle identity', () {
    expect(
      AssetExtractor.inflightKey('assets/a.mp4', bundleA),
      isNot(AssetExtractor.inflightKey('assets/a.mp4', bundleB)),
    );
  });

  test('different bundles write different cache files', () async {
    final extractor = AssetExtractor.instance;
    final pathA = await extractor.extract('assets/a.mp4', bundle: bundleA);
    final pathB = await extractor.extract('assets/a.mp4', bundle: bundleB);
    expect(pathA, isNot(pathB));
    expect(await File(pathA).readAsBytes(), [1, 2, 3]);
    expect(await File(pathB).readAsBytes(), [9, 9, 9]);
  });

  test('concurrent extract shares one future per bundle+path', () async {
    final extractor = AssetExtractor.instance;
    final futures = List.generate(4, (_) => extractor.extract('assets/a.mp4', bundle: bundleA));
    final paths = await Future.wait(futures);
    expect(paths.toSet().length, 1);
    expect(extractor.inflightForTesting, isEmpty);
  });

  test('reuses existing cache file', () async {
    final extractor = AssetExtractor.instance;
    final first = await extractor.extract('assets/a.mp4', bundle: bundleA);
    final second = await extractor.extract('assets/a.mp4', bundle: bundleA);
    expect(second, first);
  });

  test('recovers from partial cache file with wrong size', () async {
    final extractor = AssetExtractor.instance;
    final root = Directory('${tempDir.path}/xue_hua_video_snapshot/assets');
    await root.create(recursive: true);
    final cacheName = AssetExtractor.cacheFileName('assets/a.mp4', bundleA);
    final corrupt = File('${root.path}/$cacheName');
    await corrupt.writeAsBytes([1, 2]); // partial write, wrong size

    final path = await extractor.extract('assets/a.mp4', bundle: bundleA);
    expect(await File(path).readAsBytes(), [1, 2, 3]);
  });
}

class _MemoryBundle extends AssetBundle {
  _MemoryBundle(this._assets);

  final Map<String, Uint8List> _assets;

  @override
  Future<ByteData> load(String key) async {
    final bytes = _assets[key];
    if (bytes == null) {
      throw FlutterError('Asset not found: $key');
    }
    return ByteData.sublistView(bytes);
  }

  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) {
    throw UnimplementedError();
  }
}
