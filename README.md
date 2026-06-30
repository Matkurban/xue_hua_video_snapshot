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

`INTERNET` permission is declared by the plugin manifest and merged into your app automatically.

### Linux / Windows

Desktop platforms require **libmpv** on the system (Linux) or bundle libmpv with the app (Windows plugin build downloads a pinned SDK automatically during CMake configure).

## Platform permissions and configuration

Permissions depend on the [video source](#video-sources) you use. The plugin declares what it can merge; **your app** must add sandbox entitlements (macOS), cleartext/ATS rules (Android/iOS), or runtime media permissions where noted.

| Source | Android | iOS | macOS | Linux | Windows |
|--------|---------|-----|-------|-------|---------|
| **HTTPS network URL** | `INTERNET` (plugin) | ATS default | `network.client` entitlement | — | — |
| **HTTP network URL** | `INTERNET` + cleartext policy | `NSAppTransportSecurity` exception | `network.client` entitlement | — | — |
| **Local `file://` path** | Readable path or `content://` | App-accessible paths only | `files.user-selected.read-only` (sandbox) | — | — |
| **Flutter asset** | — | — | — | — | — |
| **Runtime dependency** | — | — | — | libmpv installed | libmpv via CMake |

### Android

- **Network URL**: `INTERNET` is declared in the [plugin `AndroidManifest.xml`](android/src/main/AndroidManifest.xml). Host apps do not need to re-declare it unless you use a custom manifest merge setup.
- **HTTP cleartext**: Android 9+ blocks plain HTTP by default. Add `networkSecurityConfig` or `usesCleartextTraffic` in your app manifest (the [example](example/android/app/src/main/res/xml/network_security_config.xml) enables cleartext for demos).
- **Local files**: Paths under your app sandbox and `content://` URIs (via `ContentResolver`) work without extra manifest permissions. Reading shared storage / gallery media may require `READ_MEDIA_VIDEO` or related **runtime** permissions — the plugin does not request them for you.

### iOS

- **HTTPS network**: No extra configuration (App Transport Security allows HTTPS by default).
- **HTTP cleartext**: Add an `NSAppTransportSecurity` exception in `Info.plist` for the domains you need (see [example `Info.plist`](example/ios/Runner/Info.plist)).
- **Local files**: `file://` works for paths your app can read. Files outside the sandbox require `UIDocumentPicker` or similar user-granted access.

### macOS

- **Network URL**: Sandboxed apps must set `com.apple.security.network.client` in entitlements (see [example Debug](example/macos/Runner/DebugProfile.entitlements) / [Release](example/macos/Runner/Release.entitlements)).
- **Local files**: Paths outside the app container require `com.apple.security.files.user-selected.read-only` (or a file picker that grants access).
- **Flutter asset**: Extracted to the app temp directory; no extra entitlement.

### Linux

- No app-level network or file permission declarations.
- **libmpv** must be installed on the system (`pkg-config --modversion mpv`).

### Windows

- No app-level permission declarations.
- The plugin CMake build downloads a pinned **libmpv** SDK during configuration.

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
