#include "mpv_session_decoder.h"

#include <mpv/client.h>

#include <chrono>
#include <clocale>
#include <cmath>
#include <cstring>

namespace xue_hua_video_snapshot {
namespace {

constexpr uint32_t kRgbaGrid = 64;

std::vector<uint8_t> DownsampleToRgba64(const uint8_t* data,
                                        uint32_t width,
                                        uint32_t height,
                                        uint32_t stride,
                                        bool rgb_order) {
  std::vector<uint8_t> out(kRgbaGrid * kRgbaGrid * 4);
  if (!data || width == 0 || height == 0) return out;
  const uint32_t sx = std::max(1u, width / kRgbaGrid);
  const uint32_t sy = std::max(1u, height / kRgbaGrid);
  for (uint32_t oy = 0; oy < kRgbaGrid; ++oy) {
    const uint32_t y = std::min(oy * sy, height - 1);
    const uint8_t* row = data + static_cast<size_t>(y) * stride;
    for (uint32_t ox = 0; ox < kRgbaGrid; ++ox) {
      const uint32_t x = std::min(ox * sx, width - 1);
      const uint8_t* px = row + x * 4;
      const uint8_t c0 = px[0];
      const uint8_t c1 = px[1];
      const uint8_t c2 = px[2];
      const size_t i = (static_cast<size_t>(oy) * kRgbaGrid + ox) * 4;
      out[i] = rgb_order ? c0 : c2;
      out[i + 1] = c1;
      out[i + 2] = rgb_order ? c2 : c0;
      out[i + 3] = 255;
    }
  }
  return out;
}

}  // namespace

MpvDecoderSession::MpvDecoderSession(const std::string& url) : handle_(nullptr), duration_sec_(0.0) {
  std::setlocale(LC_NUMERIC, "C");
  handle_ = mpv_create();
  if (!handle_) return;

  mpv_set_option_string(handle_, "config", "no");
  mpv_set_option_string(handle_, "terminal", "no");
  mpv_set_option_string(handle_, "msg-level", "all=error");
  mpv_set_option_string(handle_, "audio", "no");
  mpv_set_option_string(handle_, "vo", "null");
  mpv_set_option_string(handle_, "hwdec", "no");
  mpv_set_option_string(handle_, "pause", "yes");
  mpv_set_option_string(handle_, "keep-open", "yes");

  if (mpv_initialize(handle_) < 0) {
    mpv_terminate_destroy(handle_);
    handle_ = nullptr;
    return;
  }

  const char* load[] = {"loadfile", url.c_str(), "replace", nullptr};
  if (mpv_command(handle_, load) < 0) {
    mpv_terminate_destroy(handle_);
    handle_ = nullptr;
    return;
  }

  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(15);
  bool loaded = false;
  while (std::chrono::steady_clock::now() < deadline) {
    mpv_event* ev = mpv_wait_event(handle_, 0.2);
    if (!ev) continue;
    if (ev->event_id == MPV_EVENT_FILE_LOADED) {
      loaded = true;
      break;
    }
    if (ev->event_id == MPV_EVENT_END_FILE) break;
  }
  if (!loaded) {
    mpv_terminate_destroy(handle_);
    handle_ = nullptr;
    return;
  }

  double duration = 0.0;
  if (mpv_get_property(handle_, "duration", MPV_FORMAT_DOUBLE, &duration) < 0 || duration <= 0.0) {
    mpv_terminate_destroy(handle_);
    handle_ = nullptr;
    return;
  }
  duration_sec_ = duration;
}

MpvDecoderSession::~MpvDecoderSession() {
  if (handle_) mpv_terminate_destroy(handle_);
}

int64_t MpvDecoderSession::DurationMs(std::string* error) {
  std::lock_guard<std::mutex> guard(lock_);
  if (!handle_) {
    if (error) *error = "mpv session not initialized";
    return 0;
  }
  return static_cast<int64_t>(duration_sec_ * 1000.0);
}

bool MpvDecoderSession::SeekToSeconds(double seconds, std::string* error) {
  if (!handle_) {
    if (error) *error = "mpv session not initialized";
    return false;
  }
  char tbuf[64];
  std::snprintf(tbuf, sizeof(tbuf), "%.3f", seconds);
  const char* seek[] = {"seek", tbuf, "absolute+exact", nullptr};
  if (mpv_command(handle_, seek) < 0) {
    if (error) *error = "seek failed";
    return false;
  }
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(3);
  while (std::chrono::steady_clock::now() < deadline) {
    mpv_event* ev = mpv_wait_event(handle_, 0.05);
    if (!ev) break;
    if (ev->event_id == MPV_EVENT_PLAYBACK_RESTART) break;
    if (ev->event_id == MPV_EVENT_NONE) break;
  }
  return true;
}

bool MpvDecoderSession::GrabRawFrame(std::vector<uint8_t>* out_data,
                                   uint32_t* width,
                                   uint32_t* height,
                                   uint32_t* stride,
                                   bool* rgb_order,
                                   std::string* error) {
  mpv_node result_node;
  std::memset(&result_node, 0, sizeof(result_node));
  const char* shot[] = {"screenshot-raw", "video", nullptr};
  if (mpv_command_ret(handle_, shot, &result_node) < 0) {
    if (error) *error = "screenshot-raw failed";
    return false;
  }

  uint32_t rw = 0, rh = 0, rstride = 0;
  const char* fmt = nullptr;
  const uint8_t* rdata = nullptr;
  if (result_node.format == MPV_FORMAT_NODE_MAP) {
    mpv_node_list* m = result_node.u.list;
    for (int k = 0; k < m->num; ++k) {
      const char* key = m->keys[k];
      mpv_node& v = m->values[k];
      if (std::strcmp(key, "w") == 0 && v.format == MPV_FORMAT_INT64) {
        rw = static_cast<uint32_t>(v.u.int64);
      } else if (std::strcmp(key, "h") == 0 && v.format == MPV_FORMAT_INT64) {
        rh = static_cast<uint32_t>(v.u.int64);
      } else if (std::strcmp(key, "stride") == 0 && v.format == MPV_FORMAT_INT64) {
        rstride = static_cast<uint32_t>(v.u.int64);
      } else if (std::strcmp(key, "format") == 0 && v.format == MPV_FORMAT_STRING) {
        fmt = v.u.string;
      } else if (std::strcmp(key, "data") == 0 && v.format == MPV_FORMAT_BYTE_ARRAY) {
        rdata = reinterpret_cast<const uint8_t*>(v.u.ba->data);
      }
    }
  }
  mpv_free_node_contents(&result_node);

  if (!rdata || rw == 0 || rh == 0) {
    if (error) *error = "empty screenshot frame";
    return false;
  }
  *width = rw;
  *height = rh;
  *stride = rstride > 0 ? rstride : rw * 4;
  *rgb_order = fmt && (std::strcmp(fmt, "rgb0") == 0 || std::strcmp(fmt, "rgba") == 0);
  const size_t bytes = static_cast<size_t>(rh) * (*stride);
  out_data->assign(rdata, rdata + bytes);
  return true;
}

std::vector<uint8_t> MpvDecoderSession::CaptureRgba64(int64_t position_ms, std::string* error) {
  std::lock_guard<std::mutex> guard(lock_);
  std::vector<uint8_t> rgba;
  if (!handle_) {
    if (error) *error = "mpv session not initialized";
    return rgba;
  }
  const double seconds = static_cast<double>(position_ms) / 1000.0;
  if (!SeekToSeconds(seconds, error)) return rgba;

  std::vector<uint8_t> raw;
  uint32_t w = 0, h = 0, stride = 0;
  bool rgb_order = false;
  if (!GrabRawFrame(&raw, &w, &h, &stride, &rgb_order, error)) return rgba;
  return DownsampleToRgba64(raw.data(), w, h, stride, rgb_order);
}

bool MpvDecoderSession::WritePng(int64_t position_ms,
                                 const std::string& output_path,
                                 std::string* error) {
  std::lock_guard<std::mutex> guard(lock_);
  if (!handle_) {
    if (error) *error = "mpv session not initialized";
    return false;
  }
  const double seconds = static_cast<double>(position_ms) / 1000.0;
  if (!SeekToSeconds(seconds, error)) return false;
  const char* save[] = {"screenshot-to-file", output_path.c_str(), "video", nullptr};
  if (mpv_command(handle_, save) < 0) {
    if (error) *error = "screenshot-to-file failed";
    return false;
  }
  return true;
}

}  // namespace xue_hua_video_snapshot
