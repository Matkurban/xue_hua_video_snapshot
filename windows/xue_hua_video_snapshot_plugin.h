#ifndef FLUTTER_PLUGIN_XUE_HUA_VIDEO_SNAPSHOT_PLUGIN_H_
#define FLUTTER_PLUGIN_XUE_HUA_VIDEO_SNAPSHOT_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

namespace xue_hua_video_snapshot {

/// Windows plugin entry — registers Pigeon [VideoDecoderHostApi].
class XueHuaVideoSnapshotPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  XueHuaVideoSnapshotPlugin();
  virtual ~XueHuaVideoSnapshotPlugin();

  XueHuaVideoSnapshotPlugin(const XueHuaVideoSnapshotPlugin&) = delete;
  XueHuaVideoSnapshotPlugin& operator=(const XueHuaVideoSnapshotPlugin&) = delete;
};

}  // namespace xue_hua_video_snapshot

#endif  // FLUTTER_PLUGIN_XUE_HUA_VIDEO_SNAPSHOT_PLUGIN_H_
