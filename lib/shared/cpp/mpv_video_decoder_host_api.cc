#include "mpv_video_decoder_host_api.h"

#include <utility>

#include "mpv_async_runtime.h"
#include "mpv_decoder_session_registry.h"

namespace xue_hua_video_snapshot {

namespace {

template <typename Reply, typename Work>
void DispatchOnMpvWorker(Work work, std::function<void(Reply)> result) {
  EnqueueMpvWorkerTask([work = std::move(work), result = std::move(result)]() mutable {
    Reply reply_value = work();
    PostToMainThread([result = std::move(result),
                      reply_value = std::move(reply_value)]() mutable {
      result(std::move(reply_value));
    });
  });
}

}  // namespace

ErrorOr<int64_t> MpvVideoDecoderHostApi::OpenSessionOnWorker(const std::string& url) {
  auto session = std::make_unique<MpvDecoderSession>(url);
  std::string error;
  if (session->DurationMs(&error) <= 0) {
    return FlutterError("PROBE_FAILED", error.empty() ? "open session failed" : error);
  }
  const int64_t id = MpvDecoderSessionRegistry::Instance().Open(std::move(session));
  return id;
}

ErrorOr<int64_t> MpvVideoDecoderHostApi::ProbeDurationOnWorker(int64_t session_id) {
  auto* session = MpvDecoderSessionRegistry::Instance().SessionOrNull(session_id);
  if (!session) {
    return FlutterError("SESSION_ERROR", "Unknown session");
  }
  std::string error;
  const int64_t duration = session->DurationMs(&error);
  if (duration <= 0) {
    return FlutterError("PROBE_FAILED", error.empty() ? "duration unavailable" : error);
  }
  return duration;
}

ErrorOr<CaptureFrameResult> MpvVideoDecoderHostApi::CaptureFrameOnWorker(
    int64_t session_id,
    int64_t position_ms,
    const std::string* output_path) {
  auto* session = MpvDecoderSessionRegistry::Instance().SessionOrNull(session_id);
  if (!session) {
    return FlutterError("SESSION_ERROR", "Unknown session");
  }
  std::string error;
  auto rgba = session->CaptureRgba64(position_ms, &error);
  if (rgba.empty()) {
    return FlutterError("DECODE_FAILED", error.empty() ? "capture failed" : error);
  }
  std::string png_path;
  if (output_path != nullptr && !output_path->empty()) {
    if (!session->WritePng(position_ms, *output_path, &error)) {
      return FlutterError("DECODE_FAILED", error.empty() ? "png write failed" : error);
    }
    png_path = *output_path;
  }
  return CaptureFrameResult(rgba, png_path.empty() ? nullptr : &png_path);
}

std::optional<FlutterError> MpvVideoDecoderHostApi::CloseSessionOnWorker(int64_t session_id) {
  MpvDecoderSessionRegistry::Instance().Close(session_id);
  return std::nullopt;
}

void MpvVideoDecoderHostApi::OpenSession(
    const std::string& url,
    std::function<void(ErrorOr<int64_t> reply)> result) {
  DispatchOnMpvWorker<ErrorOr<int64_t>>(
      [this, url] { return OpenSessionOnWorker(url); }, std::move(result));
}

void MpvVideoDecoderHostApi::ProbeDuration(
    int64_t session_id,
    std::function<void(ErrorOr<int64_t> reply)> result) {
  DispatchOnMpvWorker<ErrorOr<int64_t>>(
      [this, session_id] { return ProbeDurationOnWorker(session_id); }, std::move(result));
}

void MpvVideoDecoderHostApi::CaptureFrame(
    int64_t session_id,
    int64_t position_ms,
    const std::string* output_path,
    std::function<void(ErrorOr<CaptureFrameResult> reply)> result) {
  std::optional<std::string> path_opt;
  if (output_path != nullptr && !output_path->empty()) {
    path_opt = *output_path;
  }
  DispatchOnMpvWorker<ErrorOr<CaptureFrameResult>>(
      [this, session_id, position_ms, path_opt = std::move(path_opt)]() mutable {
        const std::string* path_ptr =
            path_opt.has_value() ? &path_opt.value() : nullptr;
        return CaptureFrameOnWorker(session_id, position_ms, path_ptr);
      },
      std::move(result));
}

void MpvVideoDecoderHostApi::CloseSession(
    int64_t session_id,
    std::function<void(std::optional<FlutterError> reply)> result) {
  DispatchOnMpvWorker<std::optional<FlutterError>>(
      [this, session_id] { return CloseSessionOnWorker(session_id); }, std::move(result));
}

}  // namespace xue_hua_video_snapshot
