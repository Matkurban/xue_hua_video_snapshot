# xue_hua_video_snapshot

[English](README.md)

跨平台 Flutter 插件，用于从视频中抽取**非黑的封面候选帧**。插件会在时间轴上采样、按亮度过滤纯黑帧、将 PNG 写入磁盘，并按亮度降序返回结果。

## 功能

- **多来源输入** — 网络 URL、本地文件路径、Flutter asset
- **智能采样** — 跳过片头片尾各 5%，在中间区间均匀采样
- **亮度过滤** — 可配置阈值，丢弃接近纯黑的帧
- **结果排序** — 按亮度从高到低返回
- **五端支持** — Android、iOS、macOS、Linux、Windows（**不支持 Web**）

## 平台实现

| 平台      | 原生实现                     |
|---------|--------------------------|
| Android | `MediaMetadataRetriever` |
| iOS     | `AVAssetImageGenerator`  |
| macOS   | `AVAssetImageGenerator`  |
| Linux   | libmpv（短生命周期解码会话）        |
| Windows | libmpv（短生命周期解码会话）        |

## 快速开始

### 安装

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  xue_hua_video_snapshot: ^1.0.0
```

### Android

插件已在 [`android/src/main/AndroidManifest.xml`](android/src/main/AndroidManifest.xml) 声明 `INTERNET`，会合并进宿主应用，一般无需重复声明。

### Linux / Windows

桌面端依赖 **libmpv**：Linux 需系统安装；Windows 插件在 CMake 配置阶段会自动下载固定版本的 libmpv SDK。

## 各平台权限与配置

权限取决于你使用的[视频来源](#视频来源)。插件只合并它能声明的部分；**沙盒 entitlements**（macOS）、**明文/ATS 策略**（Android/iOS）、**运行时媒体权限**等由宿主应用自行配置。

| 来源                  | Android             | iOS                         | macOS                               | Linux       | Windows         |
|---------------------|---------------------|-----------------------------|-------------------------------------|-------------|-----------------|
| **HTTPS 网络 URL**    | `INTERNET`（插件）      | ATS 默认允许                    | `network.client` entitlement        | —           | —               |
| **HTTP 网络 URL**     | `INTERNET` + 明文流量策略 | `NSAppTransportSecurity` 例外 | `network.client` entitlement        | —           | —               |
| **本地 `file://` 路径** | 可读路径或 `content://`  | 仅应用可访问路径                    | `files.user-selected.read-only`（沙盒） | —           | —               |
| **Flutter asset**   | —                   | —                           | —                                   | —           | —               |
| **运行时依赖**           | —                   | —                           | —                                   | 系统安装 libmpv | CMake 下载 libmpv |

### Android

- **网络 URL**：`INTERNET` 由插件 manifest 合并；宿主应用通常无需重复声明。
- **HTTP 明文**：Android 9+ 默认禁止明文 HTTP，须在应用 `AndroidManifest.xml` 配置 `networkSecurityConfig` 或 `usesCleartextTraffic`（[example](example/android/app/src/main/res/xml/network_security_config.xml) 已包含演示配置）。
- **本地文件**：应用私有目录与 `content://`（经 `ContentResolver`）可直接使用；访问共享存储/相册媒体可能需要 `READ_MEDIA_VIDEO` 等**运行时**权限，本插件不会代为申请。

### iOS

- **HTTPS 网络**：无需额外配置（ATS 默认允许 HTTPS）。
- **HTTP 明文**：须在 `Info.plist` 为所需域名配置 `NSAppTransportSecurity` 例外（参见 [example `Info.plist`](example/ios/Runner/Info.plist)）。
- **本地文件**：`file://` 仅限应用可读路径；沙盒外文件需通过 `UIDocumentPicker` 等由用户授权。

### macOS

- **网络 URL**：沙盒应用须在 entitlements 添加 `com.apple.security.network.client`（参见 [example Debug](example/macos/Runner/DebugProfile.entitlements) / [Release](example/macos/Runner/Release.entitlements)）。
- **本地文件**：沙盒外路径须添加 `com.apple.security.files.user-selected.read-only`（或通过文件选择器授权）。
- **Flutter asset**：抽取到应用临时目录，无需额外 entitlement。

### Linux

- 无应用级网络/文件权限声明。
- 须系统安装 **libmpv**（`pkg-config --modversion mpv` 可验证）。

### Windows

- 无应用级权限声明。
- 插件 CMake 构建时会自动下载固定版本的 libmpv SDK。

### 开发者：重新生成 Pigeon 绑定

```bash
./tool/pigeon_codegen.sh
```

或分步执行：

```bash
dart run pigeon --input lib/pigeons/video_decoder_api.dart
./tool/sync_apple_spm_sources.sh
```

目录布局：

| 路径                  | 用途                                              |
|---------------------|-------------------------------------------------|
| `lib/pigeons/`      | Pigeon 接口定义（输入）                                 |
| `lib/shared/apple/` | iOS/macOS 共享 Swift（含 Pigeon 生成 + 手写 adapter）    |
| `lib/shared/cpp/`   | Linux/Windows 共享 C++（含 Pigeon 生成 + mpv adapter） |
| `lib/src/pigeon/`   | Pigeon 生成的 Dart 绑定                              |

生成目标：

- `lib/src/pigeon/video_decoder_api.g.dart`（Dart）
- `lib/shared/apple/VideoDecoderApi.swift`（Pigeon 生成）
- `lib/shared/cpp/video_decoder_api.{h,cpp}`（Pigeon 生成）

**Apple 双构建路径**（见 [Pigeon 文档](https://pub.dev/packages/pigeon)：生成代码须加入参与编译的工程）：

| 构建方式                                   | 如何引用 `lib/shared/apple/`                                               |
|----------------------------------------|------------------------------------------------------------------------|
| CocoaPods（`.podspec`）                  | `source_files` 包含 `../lib/shared/apple/**/*`                           |
| Swift Package Manager（`Package.swift`） | 源文件须在包目录内；`sync_apple_spm_sources.sh` 同步到 `ios/`、`macos/` 的 `Sources/` |

Dart 与原生 Pigeon 代码须用**同一版本** Pigeon 生成，勿跨包拆分生成物。

## 用法

```dart
import 'package:xue_hua_video_snapshot/xue_hua_video_snapshot.dart';

final snapshot = XueHuaVideoSnapshot.instance;

final frames = await snapshot.extractCoverCandidates(
  VideoSource.network('https://example.com/video.mp4'),
  count: 5,
  minBrightness: 0.08,
);

for (final frame in frames) {
  print('${frame.position} 亮度=${frame.brightness} 路径=${frame.image.path}');
}
```

### 视频来源

```dart
// 网络地址
VideoSource.network('https://example.com/video.mp4')

// 本地文件
VideoSource.file('/path/to/video.mp4')

// Flutter 资源（会先复制到临时目录）
VideoSource.asset('assets/sample.mp4')
```

### API

| 符号                                                                  | 说明                                              |
|---------------------------------------------------------------------|-------------------------------------------------|
| `XueHuaVideoSnapshot.instance`                                      | 插件单例                                            |
| `extractCoverCandidates(source, {count, minBrightness, outputDir})` | 抽取封面候选帧                                         |
| `VideoCoverFrame`                                                   | 结果：`image`（PNG `XFile`）、`position`、`brightness` |
| `VideoSource`                                                       | 密封类型，支持 `network` / `file` / `asset`            |

## 示例

参见 [`example/`](example/)：输入 URL 后点击「抽取封面」，展示缩略图、时间戳与亮度。

```bash
cd example
flutter run
```

## 许可证

见 [LICENSE](LICENSE)。
