import 'dart:io';
import 'dart:typed_data';

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
    bundleA = _MemoryBundle({'assets/a.mp4': Uint8List.fromList([1, 2, 3])});
    bundleB = _MemoryBundle({'assets/a.mp4': Uint8List.fromList([9, 9, 9])});
    AssetExtractor.debugReplaceInstance(
      AssetExtractor(tempDirectory: () async => tempDir),
    );
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
    final futures = List.generate(
      4,
      (_) => extractor.extract('assets/a.mp4', bundle: bundleA),
    );
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
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) {
    throw UnimplementedError();
  }
}
