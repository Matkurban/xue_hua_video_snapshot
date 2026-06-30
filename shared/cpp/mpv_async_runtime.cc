#include "mpv_async_runtime.h"

#include <condition_variable>
#include <functional>
#include <mutex>
#include <queue>
#include <thread>
#include <utility>

namespace xue_hua_video_snapshot {
namespace {

std::function<void(MainThreadTask)> g_main_poster;
std::mutex g_main_poster_mutex;

class MpvWorker {
 public:
  static MpvWorker& Instance() {
    static MpvWorker worker;
    return worker;
  }

  void Enqueue(std::function<void()> task) {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      tasks_.push(std::move(task));
    }
    cv_.notify_one();
  }

 private:
  MpvWorker() : thread_([this] { Run(); }) {}
  ~MpvWorker() {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      stopping_ = true;
    }
    cv_.notify_all();
    if (thread_.joinable()) thread_.join();
  }

  void Run() {
    while (true) {
      std::function<void()> task;
      {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] { return stopping_ || !tasks_.empty(); });
        if (stopping_ && tasks_.empty()) return;
        task = std::move(tasks_.front());
        tasks_.pop();
      }
      task();
    }
  }

  std::thread thread_;
  std::mutex mutex_;
  std::condition_variable cv_;
  std::queue<std::function<void()>> tasks_;
  bool stopping_ = false;
};

}  // namespace

void SetMainThreadPoster(std::function<void(MainThreadTask)> poster) {
  std::lock_guard<std::mutex> lock(g_main_poster_mutex);
  g_main_poster = std::move(poster);
}

void PostToMainThread(MainThreadTask task) {
  std::function<void(MainThreadTask)> poster;
  {
    std::lock_guard<std::mutex> lock(g_main_poster_mutex);
    poster = g_main_poster;
  }
  if (poster) {
    poster(std::move(task));
    return;
  }
  task();
}

void EnqueueMpvWorkerTask(std::function<void()> task) {
  MpvWorker::Instance().Enqueue(std::move(task));
}

}  // namespace xue_hua_video_snapshot
