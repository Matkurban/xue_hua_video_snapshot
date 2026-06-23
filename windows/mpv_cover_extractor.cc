#include "mpv_cover_extractor.h"

#include <mpv/client.h>

#include <algorithm>
#include <chrono>
#include <clocale>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <sstream>

namespace xue_hua_video_snapshot {

namespace {

// Compute average Rec.601 luma over a RGB/BGR(A) buffer, sampling on a 64x64
// grid for speed. `bytes_per_pixel` should be 3 or 4; for 4, the alpha byte is
// ignored. `rgb_order` = true for RGB(A), false for BGR(A).
double AverageBrightness(const uint8_t* data,
                         uint32_t width,
                         uint32_t height,
                         uint32_t stride_bytes,
                         int bytes_per_pixel,
                         bool rgb_order) {
  if (!data || width == 0 || height == 0) return 0.0;
  constexpr uint32_t kGrid = 64;
  const uint32_t sx = std::max(1u, width / kGrid);
  const uint32_t sy = std::max(1u, height / kGrid);
  double total = 0.0;
  uint64_t count = 0;
  for (uint32_t y = 0; y < height; y += sy) {
    const uint8_t* row = data + static_cast<size_t>(y) * stride_bytes;
    for (uint32_t x = 0; x < width; x += sx) {
      const uint8_t* px = row + x * bytes_per_pixel;
      uint8_t c0 = px[0], c1 = px[1], c2 = px[2];
      double r = (rgb_order ? c0 : c2) / 255.0;
      double g = c1 / 255.0;
      double b = (rgb_order ? c2 : c0) / 255.0;
      total += 0.299 * r + 0.587 * g + 0.114 * b;
      count++;
    }
  }
  return count > 0 ? total / static_cast<double>(count) : 0.0;
}

int SetOptionString(mpv_handle* h, const char* name, const char* value) {
  return mpv_set_option_string(h, name, value);
}

}  // namespace

// ────────────────────────────────────────────────────────────────────────────
// Cover extraction (static, uses a short-lived mpv_handle).
// ────────────────────────────────────────────────────────────────────────────

std::vector<CoverFrame> MpvCoverExtractor::ExtractCovers(const std::string& url,
                                                       int count,
                                                       int candidates,
                                                       double min_brightness,
                                                       const std::string& output_dir,
                                                       std::string* error) {
  std::vector<CoverFrame> result;
  if (count <= 0) return result;
  if (candidates < count) candidates = count * 3;

  std::setlocale(LC_NUMERIC, "C");
  mpv_handle* h = mpv_create();
  if (!h) {
    if (error) *error = "mpv_create failed";
    return result;
  }
  struct Guard {
    mpv_handle* h;
    ~Guard() { if (h) mpv_terminate_destroy(h); }
  } guard{h};

  SetOptionString(h, "config", "no");
  SetOptionString(h, "terminal", "no");
  SetOptionString(h, "msg-level", "all=error");
  SetOptionString(h, "audio", "no");
  SetOptionString(h, "vo", "null");
  SetOptionString(h, "hwdec", "no");
  SetOptionString(h, "pause", "yes");
  SetOptionString(h, "keep-open", "yes");

  if (mpv_initialize(h) < 0) {
    if (error) *error = "mpv_initialize failed";
    return result;
  }

  // Load the file, wait for it to actually be loaded.
  const char* load[] = {"loadfile", url.c_str(), "replace", nullptr};
  if (mpv_command(h, load) < 0) {
    if (error) *error = "loadfile failed";
    return result;
  }

  // Pump events until we see MPV_EVENT_FILE_LOADED (with timeout).
  const auto deadline =
      std::chrono::steady_clock::now() + std::chrono::seconds(15);
  bool loaded = false;
  while (std::chrono::steady_clock::now() < deadline) {
    mpv_event* ev = mpv_wait_event(h, 0.2);
    if (!ev) continue;
    if (ev->event_id == MPV_EVENT_FILE_LOADED) { loaded = true; break; }
    if (ev->event_id == MPV_EVENT_END_FILE) break;
  }
  if (!loaded) {
    if (error) *error = "timeout waiting for file load";
    return result;
  }

  double duration = 0.0;
  if (mpv_get_property(h, "duration", MPV_FORMAT_DOUBLE, &duration) < 0 ||
      duration <= 0.0) {
    if (error) *error = "could not read duration";
    return result;
  }

  // Build sample times — skip first/last 5%, sample `n` positions evenly.
  int n = std::max(candidates, count);
  const double lower = duration * 0.05;
  const double upper = duration * 0.95;
  const double span = std::max(upper - lower, 0.1);

  // Ensure output directory exists — best effort (caller should also ensure).
  // Here we rely on the caller to pre-create; if not, screenshot-to-file fails.

  auto hash_url = std::to_string(std::hash<std::string>{}(url));

  for (int i = 0; i < n && static_cast<int>(result.size()) < count; ++i) {
    double t = lower + span * (i + 0.5) / n;
    // Seek to `t`.
    char tbuf[64];
    std::snprintf(tbuf, sizeof(tbuf), "%.3f", t);
    const char* seek[] = {"seek", tbuf, "absolute+exact", nullptr};
    if (mpv_command(h, seek) < 0) continue;

    // Drain events briefly to let the seek settle.
    const auto step_deadline =
        std::chrono::steady_clock::now() + std::chrono::seconds(3);
    while (std::chrono::steady_clock::now() < step_deadline) {
      mpv_event* ev = mpv_wait_event(h, 0.05);
      if (!ev) break;
      if (ev->event_id == MPV_EVENT_PLAYBACK_RESTART) break;
      if (ev->event_id == MPV_EVENT_NONE) break;
    }

    // screenshot-raw: returns MPV_FORMAT_NODE_MAP with keys w/h/stride/format/data.
    mpv_node result_node;
    std::memset(&result_node, 0, sizeof(result_node));
    const char* shot[] = {"screenshot-raw", "video", nullptr};
    int rc = mpv_command_ret(h, shot, &result_node);
    if (rc < 0) continue;

    // Parse the node: { w, h, stride, format, data }
    uint32_t rw = 0, rh = 0, rstride = 0;
    const char* fmt = nullptr;
    const uint8_t* rdata = nullptr;
    size_t rdata_size = 0;
    if (result_node.format == MPV_FORMAT_NODE_MAP) {
      mpv_node_list* m = result_node.u.list;
      for (int k = 0; k < m->num; ++k) {
        const char* key = m->keys[k];
        mpv_node& v = m->values[k];
        if (std::strcmp(key, "w") == 0 && v.format == MPV_FORMAT_INT64) {
          rw = static_cast<uint32_t>(v.u.int64);
        } else if (std::strcmp(key, "h") == 0 &&
                   v.format == MPV_FORMAT_INT64) {
          rh = static_cast<uint32_t>(v.u.int64);
        } else if (std::strcmp(key, "stride") == 0 &&
                   v.format == MPV_FORMAT_INT64) {
          rstride = static_cast<uint32_t>(v.u.int64);
        } else if (std::strcmp(key, "format") == 0 &&
                   v.format == MPV_FORMAT_STRING) {
          fmt = v.u.string;
        } else if (std::strcmp(key, "data") == 0 &&
                   v.format == MPV_FORMAT_BYTE_ARRAY) {
          rdata = reinterpret_cast<const uint8_t*>(v.u.ba->data);
          rdata_size = v.u.ba->size;
        }
      }
    }

    double brightness = 0.0;
    if (rw > 0 && rh > 0 && rdata && rdata_size >= static_cast<size_t>(rh) *
                                                         rstride) {
      // mpv screenshot-raw returns BGR0 by default on little-endian (format
      // string "bgr0"). Treat unknown formats as BGR0 too since that is the
      // documented default.
      bool rgb_order = (fmt && (std::strcmp(fmt, "rgb0") == 0 ||
                                std::strcmp(fmt, "rgba") == 0));
      brightness = AverageBrightness(rdata, rw, rh, rstride, 4, rgb_order);
    }

    mpv_free_node_contents(&result_node);

    if (brightness < min_brightness) continue;

    // Write the PNG via mpv's screenshot-to-file for simplicity.
    int64_t t_ms = static_cast<int64_t>(t * 1000);
    std::ostringstream name;
    name << output_dir;
    if (!output_dir.empty() && output_dir.back() != '/' &&
        output_dir.back() != '\\') {
      name << '/';
    }
    name << "cover-" << hash_url << "-" << t_ms << ".png";
    std::string out_path = name.str();
    const char* save[] = {"screenshot-to-file", out_path.c_str(), "video",
                          nullptr};
    if (mpv_command(h, save) < 0) continue;

    CoverFrame cf;
    cf.path = out_path;
    cf.position_ms = t_ms;
    cf.brightness = brightness;
    result.push_back(std::move(cf));
  }

  std::sort(result.begin(), result.end(),
            [](const CoverFrame& a, const CoverFrame& b) {
              return a.brightness > b.brightness;
            });
  if (static_cast<int>(result.size()) > count) result.resize(count);
  return result;
}

}  // namespace xue_hua_video_snapshot
