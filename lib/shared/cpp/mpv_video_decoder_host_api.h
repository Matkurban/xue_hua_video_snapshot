#ifndef XUE_HUA_VIDEO_SNAPSHOT_MPV_VIDEO_DECODER_HOST_API_H_
#define XUE_HUA_VIDEO_SNAPSHOT_MPV_VIDEO_DECODER_HOST_API_H_

#include <cstdint>
#include <functional>
#include <optional>
#include <string>

#include "video_decoder_api.h"

namespace xue_hua_video_snapshot {

class MpvVideoDecoderHostApi : public VideoDecoderHostApi {
 public:
  void OpenSession(const std::string& url,
                   std::function<void(ErrorOr<int64_t> reply)> result) override;
  void ProbeDuration(int64_t session_id,
                     std::function<void(ErrorOr<int64_t> reply)> result) override;
  void CaptureFrame(int64_t session_id,
                    int64_t position_ms,
                    const std::string* output_path,
                    std::function<void(ErrorOr<CaptureFrameResult> reply)> result) override;
  void CloseSession(int64_t session_id,
                    std::function<void(std::optional<FlutterError> reply)> result) override;

 private:
  ErrorOr<int64_t> OpenSessionOnWorker(const std::string& url);
  ErrorOr<int64_t> ProbeDurationOnWorker(int64_t session_id);
  ErrorOr<CaptureFrameResult> CaptureFrameOnWorker(int64_t session_id,
                                                   int64_t position_ms,
                                                   const std::string* output_path);
  std::optional<FlutterError> CloseSessionOnWorker(int64_t session_id);
};

}  // namespace xue_hua_video_snapshot

#endif  // XUE_HUA_VIDEO_SNAPSHOT_MPV_VIDEO_DECODER_HOST_API_H_
