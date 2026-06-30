#include "mpv_decoder_session_registry.h"

namespace xue_hua_video_snapshot {

MpvDecoderSessionRegistry& MpvDecoderSessionRegistry::Instance() {
  static MpvDecoderSessionRegistry registry;
  return registry;
}

int64_t MpvDecoderSessionRegistry::Open(std::unique_ptr<MpvDecoderSession> session) {
  std::lock_guard<std::mutex> lock(mutex_);
  const int64_t id = next_session_id_++;
  sessions_[id] = std::move(session);
  return id;
}

MpvDecoderSession* MpvDecoderSessionRegistry::SessionOrNull(int64_t session_id) {
  std::lock_guard<std::mutex> lock(mutex_);
  auto it = sessions_.find(session_id);
  if (it == sessions_.end()) return nullptr;
  return it->second.get();
}

void MpvDecoderSessionRegistry::Close(int64_t session_id) {
  std::lock_guard<std::mutex> lock(mutex_);
  sessions_.erase(session_id);
}

}  // namespace xue_hua_video_snapshot
