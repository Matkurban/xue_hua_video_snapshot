#include "xue_hua_video_snapshot_plugin.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <flutter/standard_method_codec.h>
#include <shlobj.h>
#include <windows.h>

#include <filesystem>
#include <memory>
#include <string>
#include <vector>

#include "mpv_cover_extractor.h"

namespace xue_hua_video_snapshot {

namespace {

std::string WideToUtf8(const std::wstring& w) {
  if (w.empty()) return {};
  int sz = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), (int)w.size(), nullptr, 0, nullptr, nullptr);
  std::string s(sz, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w.c_str(), (int)w.size(), s.data(), sz, nullptr, nullptr);
  return s;
}

std::string DefaultCoverDir() {
  wchar_t tmp[MAX_PATH] = {0};
  GetTempPathW(MAX_PATH, tmp);
  std::wstring dir = std::wstring(tmp) + L"xue_hua_video_snapshot\\covers";
  std::error_code ec;
  std::filesystem::create_directories(dir, ec);
  return WideToUtf8(dir);
}

template <typename T>
const T* GetArg(const flutter::EncodableMap* map, const char* key) {
  auto it = map->find(flutter::EncodableValue(key));
  if (it == map->end()) return nullptr;
  return std::get_if<T>(&it->second);
}

}  // namespace

void XueHuaVideoSnapshotPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<XueHuaVideoSnapshotPlugin>();
  auto* raw = plugin.get();

  auto method_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "xue_hua_video_snapshot",
      &flutter::StandardMethodCodec::GetInstance());
  method_channel->SetMethodCallHandler(
      [raw](const auto& call, auto result) { raw->HandleMethodCall(call, std::move(result)); });
  plugin->method_channel_ = std::move(method_channel);

  registrar->AddPlugin(std::move(plugin));
}

XueHuaVideoSnapshotPlugin::XueHuaVideoSnapshotPlugin() = default;

XueHuaVideoSnapshotPlugin::~XueHuaVideoSnapshotPlugin() = default;

void XueHuaVideoSnapshotPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() != "extractCovers") {
    result->NotImplemented();
    return;
  }

  const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
  std::string url;
  int count = 5;
  int candidates = 15;
  double min_brightness = 0.08;
  std::string output_dir;

  if (args) {
    if (const auto* v = GetArg<std::string>(args, "url")) url = *v;
    if (const auto* v = GetArg<int32_t>(args, "count")) count = *v;
    if (const auto* v = GetArg<int32_t>(args, "candidates")) candidates = *v;
    if (const auto* v = GetArg<double>(args, "minBrightness")) min_brightness = *v;
    if (const auto* v = GetArg<std::string>(args, "outputDir")) output_dir = *v;
  }

  if (output_dir.empty()) output_dir = DefaultCoverDir();
  else std::filesystem::create_directories(output_dir);

  auto frames = MpvCoverExtractor::ExtractCovers(
      url, count, candidates, min_brightness, output_dir);

  flutter::EncodableList list;
  for (const auto& f : frames) {
    flutter::EncodableMap m;
    m[flutter::EncodableValue("path")] = flutter::EncodableValue(f.path);
    m[flutter::EncodableValue("positionMs")] = flutter::EncodableValue(f.position_ms);
    m[flutter::EncodableValue("brightness")] = flutter::EncodableValue(f.brightness);
    list.push_back(flutter::EncodableValue(m));
  }
  result->Success(flutter::EncodableValue(list));
}

}  // namespace xue_hua_video_snapshot
