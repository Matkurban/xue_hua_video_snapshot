// Linux plugin — registers Pigeon VideoDecoderHostApi (libmpv).

#include "include/xue_hua_video_snapshot/xue_hua_video_snapshot_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <clocale>
#include <functional>
#include <memory>

#include "mpv_async_runtime.h"
#include "mpv_video_decoder_host_api.h"
#include "video_decoder_api.h"

#define XUE_HUA_VIDEO_SNAPSHOT_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), xue_hua_video_snapshot_plugin_get_type(), XueHuaVideoSnapshotPlugin))

struct _XueHuaVideoSnapshotPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(XueHuaVideoSnapshotPlugin, xue_hua_video_snapshot_plugin, g_object_get_type())

static std::unique_ptr<xue_hua_video_snapshot::MpvVideoDecoderHostApi> g_decoder_api;

static void xue_hua_video_snapshot_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(xue_hua_video_snapshot_plugin_parent_class)->dispose(object);
}

static void xue_hua_video_snapshot_plugin_class_init(XueHuaVideoSnapshotPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = xue_hua_video_snapshot_plugin_dispose;
}

static void xue_hua_video_snapshot_plugin_init(XueHuaVideoSnapshotPlugin* self) {}

static void InstallLinuxMainThreadPoster() {
  xue_hua_video_snapshot::SetMainThreadPoster(
      [](xue_hua_video_snapshot::MainThreadTask task) {
        auto* heap_task =
            new xue_hua_video_snapshot::MainThreadTask(std::move(task));
        g_idle_add(
            +[](gpointer data) -> gboolean {
              std::unique_ptr<xue_hua_video_snapshot::MainThreadTask> owned(
                  static_cast<xue_hua_video_snapshot::MainThreadTask*>(data));
              (*owned)();
              return G_SOURCE_REMOVE;
            },
            heap_task);
      });
}

void xue_hua_video_snapshot_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  std::setlocale(LC_NUMERIC, "C");
  InstallLinuxMainThreadPoster();

  g_decoder_api = std::make_unique<xue_hua_video_snapshot::MpvVideoDecoderHostApi>();
  xue_hua_video_snapshot::VideoDecoderHostApi::SetUp(
      fl_plugin_registrar_get_messenger(registrar),
      g_decoder_api.get());

  g_object_new(xue_hua_video_snapshot_plugin_get_type(), nullptr);
}
