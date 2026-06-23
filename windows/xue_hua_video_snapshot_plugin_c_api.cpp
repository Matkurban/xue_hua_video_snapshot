#include "include/xue_hua_video_snapshot/xue_hua_video_snapshot_plugin_c_api.h"

#include "xue_hua_video_snapshot_plugin.h"

#include <flutter/plugin_registrar_windows.h>

void XueHuaVideoSnapshotPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  xue_hua_video_snapshot::XueHuaVideoSnapshotPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
