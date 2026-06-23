#ifndef FLUTTER_PLUGIN_XUE_HUA_VIDEO_SNAPSHOT_PLUGIN_H_
#define FLUTTER_PLUGIN_XUE_HUA_VIDEO_SNAPSHOT_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace xue_hua_video_snapshot {

/// Windows 插件主类，通过 libmpv 抽取视频封面候选帧。
/// Windows plugin main class for cover extraction via libmpv.
class XueHuaVideoSnapshotPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  XueHuaVideoSnapshotPlugin();
  virtual ~XueHuaVideoSnapshotPlugin();

  XueHuaVideoSnapshotPlugin(const XueHuaVideoSnapshotPlugin&) = delete;
  XueHuaVideoSnapshotPlugin& operator=(const XueHuaVideoSnapshotPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;
};

}  // namespace xue_hua_video_snapshot

#endif  // FLUTTER_PLUGIN_XUE_HUA_VIDEO_SNAPSHOT_PLUGIN_H_
