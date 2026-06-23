# xue_hua_video_snapshot

[中文文档](README_ZH.md)

A cross-platform Flutter plugin that extracts **non-black cover candidate frames** from video files. It samples frames across the timeline, filters dark frames by brightness, writes PNGs to disk, and returns metadata sorted by brightness.

## Features

- **Multi-source input** — network URL, local file path, or Flutter asset
- **Smart sampling** — skips the first/last 5% of the video, evenly samples candidate positions
- **Brightness filter** — drops near-black frames with a configurable threshold
- **Sorted results** — returns the brightest candidates first
- **5-platform support** — Android, iOS, macOS, Linux, Windows (Web is **not** supported)

## Platform Engines

| Platform | Native Engine |
|----------|---------------|
| Android  | `MediaMetadataRetriever` |
| iOS      | `AVAssetImageGenerator` |
| macOS    | `AVAssetImageGenerator` |
| Linux    | libmpv (short-lived decode session) |
| Windows  | libmpv (short-lived decode session) |

## Getting Started

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  xue_hua_video_snapshot: ^1.0.0
```

### Android

`INTERNET` permission is declared by the plugin for network URLs. Cleartext HTTP is allowed in the example app via `network_security_config.xml` when testing HTTP endpoints.

### Linux / Windows

Desktop platforms require **libmpv** on the system (Linux) or bundle libmpv with the app (Windows plugin build downloads a pinned SDK automatically during CMake configure).

## Usage

```dart
import 'package:xue_hua_video_snapshot/xue_hua_video_snapshot.dart';

final snapshot = XueHuaVideoSnapshot.instance;

final frames = await snapshot.extractCoverCandidates(
  VideoSource.network('https://example.com/video.mp4'),
  count: 5,
  minBrightness: 0.08,
);

for (final frame in frames) {
  print('${frame.position} brightness=${frame.brightness} path=${frame.image.path}');
}
```

### Video sources

```dart
// Network URL
VideoSource.network('https://example.com/video.mp4')

// Local file
VideoSource.file('/path/to/video.mp4')

// Flutter asset (copied to temp dir first)
VideoSource.asset('assets/sample.mp4')
```

### API

| Symbol | Description |
|--------|-------------|
| `XueHuaVideoSnapshot.instance` | Plugin singleton |
| `extractCoverCandidates(source, {count, minBrightness, outputDir})` | Extract cover candidates |
| `VideoCoverFrame` | Result: `image` (`XFile` PNG), `position`, `brightness` |
| `VideoSource` | Sealed type with `network` / `file` / `asset` constructors |

## Example

See the [`example/`](example/) app for a minimal UI that extracts covers from a sample URL and displays thumbnails.

```bash
cd example
flutter run
```

## License

See [LICENSE](LICENSE).
