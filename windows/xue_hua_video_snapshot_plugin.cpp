#include "xue_hua_video_snapshot_plugin.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

#include <clocale>
#include <functional>
#include <memory>
#include <optional>

#include "mpv_async_runtime.h"
#include "mpv_video_decoder_host_api.h"
#include "video_decoder_api.h"

namespace xue_hua_video_snapshot {

namespace {

constexpr UINT kMpvTaskMessage = WM_APP + 1001;

HWND g_main_hwnd = nullptr;
int g_window_proc_delegate_id = 0;
std::unique_ptr<MpvVideoDecoderHostApi> g_decoder_api;

std::optional<LRESULT> HandleMpvTaskMessage(HWND hwnd,
                                            UINT message,
                                            WPARAM wparam,
                                            LPARAM lparam) {
  if (message != kMpvTaskMessage) {
    return std::nullopt;
  }
  auto* task = reinterpret_cast<MainThreadTask*>(lparam);
  std::unique_ptr<MainThreadTask> owned(task);
  if (owned) {
    (*owned)();
  }
  return static_cast<LRESULT>(0);
}

void InstallWindowsMainThreadPoster(flutter::PluginRegistrarWindows* registrar) {
  if (auto* view = registrar->GetView()) {
    g_main_hwnd = view->GetNativeWindow();
  }
  g_window_proc_delegate_id = registrar->RegisterTopLevelWindowProcDelegate(
      HandleMpvTaskMessage);

  SetMainThreadPoster([](MainThreadTask task) {
    if (!g_main_hwnd) {
      task();
      return;
    }
    auto* heap_task = new MainThreadTask(std::move(task));
    PostMessage(g_main_hwnd, kMpvTaskMessage, 0, reinterpret_cast<LPARAM>(heap_task));
  });
}

}  // namespace

void XueHuaVideoSnapshotPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  std::setlocale(LC_NUMERIC, "C");
  InstallWindowsMainThreadPoster(registrar);

  g_decoder_api = std::make_unique<MpvVideoDecoderHostApi>();
  VideoDecoderHostApi::SetUp(registrar->messenger(), g_decoder_api.get());
  registrar->AddPlugin(std::make_unique<XueHuaVideoSnapshotPlugin>());
}

XueHuaVideoSnapshotPlugin::XueHuaVideoSnapshotPlugin() = default;

XueHuaVideoSnapshotPlugin::~XueHuaVideoSnapshotPlugin() = default;

}  // namespace xue_hua_video_snapshot
