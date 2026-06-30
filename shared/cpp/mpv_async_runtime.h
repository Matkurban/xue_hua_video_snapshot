#ifndef XUE_HUA_VIDEO_SNAPSHOT_MPV_ASYNC_RUNTIME_H_
#define XUE_HUA_VIDEO_SNAPSHOT_MPV_ASYNC_RUNTIME_H_

#include <functional>

namespace xue_hua_video_snapshot {

using MainThreadTask = std::function<void()>;

/// Installs the platform-specific main-thread dispatcher (GTK idle / Win32 PostMessage).
void SetMainThreadPoster(std::function<void(MainThreadTask)> poster);

/// Runs [task] on the UI / platform thread.
void PostToMainThread(MainThreadTask task);

/// Queues [task] on the dedicated mpv worker thread.
void EnqueueMpvWorkerTask(std::function<void()> task);

}  // namespace xue_hua_video_snapshot

#endif  // XUE_HUA_VIDEO_SNAPSHOT_MPV_ASYNC_RUNTIME_H_
