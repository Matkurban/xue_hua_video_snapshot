// libmpv-backed cover extraction used by Linux and Windows plugins.
//
// Design:
// * Uses a short-lived mpv_handle per extraction request.
// * Cover frames are written as PNG via mpv's `screenshot-to-file` command.
//
// Nothing in this file depends on Flutter — only libmpv and the C++ standard
// library.

#ifndef XUE_HUA_VIDEO_SNAPSHOT_MPV_COVER_EXTRACTOR_H_
#define XUE_HUA_VIDEO_SNAPSHOT_MPV_COVER_EXTRACTOR_H_

#include <cstdint>
#include <string>
#include <vector>

namespace xue_hua_video_snapshot {

struct CoverFrame {
  std::string path;     // absolute path of a PNG written to disk
  int64_t position_ms;  // requested sample position in milliseconds
  double brightness;    // average luma 0..1 (Rec.601)
};

class MpvCoverExtractor {
 public:
  /// 从视频 URL 中抽取若干非黑的候选封面帧。
  /// Extract non-black cover candidates from a media URL.
  static std::vector<CoverFrame> ExtractCovers(const std::string& url,
                                               int count,
                                               int candidates,
                                               double min_brightness,
                                               const std::string& output_dir,
                                               std::string* error = nullptr);
};

}  // namespace xue_hua_video_snapshot

#endif  // XUE_HUA_VIDEO_SNAPSHOT_MPV_COVER_EXTRACTOR_H_
