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

| 平台 | 原生实现 |
|------|----------|
| Android | `MediaMetadataRetriever` |
| iOS | `AVAssetImageGenerator` |
| macOS | `AVAssetImageGenerator` |
| Linux | libmpv（短生命周期解码会话） |
| Windows | libmpv（短生命周期解码会话） |

## 快速开始

### 安装

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  xue_hua_video_snapshot: ^1.0.0
```

### Android

插件已声明 `INTERNET` 权限。若测试 HTTP 地址，需在应用中配置明文流量策略（示例项目已包含 `network_security_config.xml`）。

### Linux / Windows

桌面端依赖 **libmpv**：Linux 需系统安装；Windows 插件在 CMake 配置阶段会自动下载固定版本的 libmpv SDK。

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

| 符号 | 说明 |
|------|------|
| `XueHuaVideoSnapshot.instance` | 插件单例 |
| `extractCoverCandidates(source, {count, minBrightness, outputDir})` | 抽取封面候选帧 |
| `VideoCoverFrame` | 结果：`image`（PNG `XFile`）、`position`、`brightness` |
| `VideoSource` | 密封类型，支持 `network` / `file` / `asset` |

## 示例

参见 [`example/`](example/)：输入 URL 后点击「抽取封面」，展示缩略图、时间戳与亮度。

```bash
cd example
flutter run
```

## 许可证

见 [LICENSE](LICENSE)。
