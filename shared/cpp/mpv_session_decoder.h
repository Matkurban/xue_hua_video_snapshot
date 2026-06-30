#ifndef XUE_HUA_VIDEO_SNAPSHOT_MPV_SESSION_DECODER_H_
#define XUE_HUA_VIDEO_SNAPSHOT_MPV_SESSION_DECODER_H_

#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

struct mpv_handle;

namespace xue_hua_video_snapshot {

/// Short-lived mpv decode session for one media URL.
class MpvDecoderSession {
 public:
  explicit MpvDecoderSession(const std::string& url);
  ~MpvDecoderSession();

  MpvDecoderSession(const MpvDecoderSession&) = delete;
  MpvDecoderSession& operator=(const MpvDecoderSession&) = delete;

  int64_t DurationMs(std::string* error);
  std::vector<uint8_t> CaptureRgba64(int64_t position_ms, std::string* error);
  bool WritePng(int64_t position_ms, const std::string& output_path, std::string* error);

 private:
  bool SeekToSeconds(double seconds, std::string* error);
  bool GrabRawFrame(std::vector<uint8_t>* out_data,
                    uint32_t* width,
                    uint32_t* height,
                    uint32_t* stride,
                    bool* rgb_order,
                    std::string* error);

  mpv_handle* handle_;
  double duration_sec_;
  std::mutex lock_;
};

}  // namespace xue_hua_video_snapshot

#endif  // XUE_HUA_VIDEO_SNAPSHOT_MPV_SESSION_DECODER_H_
