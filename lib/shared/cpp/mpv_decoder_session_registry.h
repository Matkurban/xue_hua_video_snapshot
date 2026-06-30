#ifndef XUE_HUA_VIDEO_SNAPSHOT_MPV_DECODER_SESSION_REGISTRY_H_
#define XUE_HUA_VIDEO_SNAPSHOT_MPV_DECODER_SESSION_REGISTRY_H_

#include <cstdint>
#include <map>
#include <memory>
#include <mutex>

#include "mpv_session_decoder.h"

namespace xue_hua_video_snapshot {

/// Plugin-scoped session registry — shared across host API re-instantiation.
class MpvDecoderSessionRegistry {
 public:
  static MpvDecoderSessionRegistry& Instance();

  int64_t Open(std::unique_ptr<MpvDecoderSession> session);
  MpvDecoderSession* SessionOrNull(int64_t session_id);
  void Close(int64_t session_id);

 private:
  MpvDecoderSessionRegistry() = default;

  std::mutex mutex_;
  std::map<int64_t, std::unique_ptr<MpvDecoderSession>> sessions_;
  int64_t next_session_id_ = 1;
};

}  // namespace xue_hua_video_snapshot

#endif  // XUE_HUA_VIDEO_SNAPSHOT_MPV_DECODER_SESSION_REGISTRY_H_
