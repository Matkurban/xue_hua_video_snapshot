# Changelog

## 1.1.0

### Breaking

- Replaced `extractCovers` MethodChannel with Pigeon `VideoDecoderHostApi` seam.
- `extractCoverCandidates` now throws [`SnapshotException`](lib/src/video_decoder_port.dart)
  when duration probing or frame decoding fails. An empty list still means no frame passed
  the brightness threshold.

### Added

- Dart `CoverExtraction` module — unified sampling policy, Rec.601 brightness, sort/trim.
- Pigeon contract in [`lib/pigeons/video_decoder_api.dart`](lib/pigeons/video_decoder_api.dart).
- Dart unit tests in [`test/cover_extraction_test.dart`](test/cover_extraction_test.dart).

### Changed

- Native shared code under `lib/shared/`:
  - `lib/shared/apple/` — Pigeon `VideoDecoderApi.swift` + `AppleVideoDecoderHostApi.swift` (iOS & macOS)
  - `lib/shared/cpp/` — Pigeon bindings + mpv decoder stack (Linux & Windows)
- Pigeon contract input in `lib/pigeons/`; outputs generate into `lib/src/pigeon/` and `lib/shared/`.
- `AssetExtractor` is an injectable instance (`AssetExtractor.instance`) instead of a static-only API.

### Fixed

- Linux/Windows: mpv decode work runs on a dedicated worker thread; Pigeon replies are
  posted back to the UI thread (`g_idle_add` on Linux, `PostMessage` on Windows).
- `AssetExtractor` inflight/cache keys now include `AssetBundle` identity — custom bundles no longer race or reuse wrong files.
- `FileVideoSource.identity` and `resolveToNativeUrl()` use the same `normalizeFileUri` helper.

### Removed

- Native cover-extraction policy from Android plugin, `CoverExtractor.swift`, and
  `mpv_cover_extractor`.

## 1.0.0

- `XueHuaVideoSnapshot.extractCoverCandidates()` — 从视频中抽取非黑封面候选帧
- `VideoSource.network` / `file` / `asset` 三种视频来源
- `VideoCoverFrame` — PNG 路径、时间戳、亮度评分
- 支持 Android、iOS、macOS、Linux、Windows
