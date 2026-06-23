// Linux plugin implementation — libmpv cover extraction.

#include "include/xue_hua_video_snapshot/xue_hua_video_snapshot_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <clocale>
#include <cstring>
#include <string>

#include "mpv_cover_extractor.h"

using xue_hua_video_snapshot::CoverFrame;
using xue_hua_video_snapshot::MpvCoverExtractor;

#define XUE_HUA_VIDEO_SNAPSHOT_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), xue_hua_video_snapshot_plugin_get_type(), XueHuaVideoSnapshotPlugin))

struct _XueHuaVideoSnapshotPlugin {
  GObject parent_instance;
  FlMethodChannel* method_channel;
};

G_DEFINE_TYPE(XueHuaVideoSnapshotPlugin, xue_hua_video_snapshot_plugin, g_object_get_type())

static gchar* default_cover_dir() {
  const gchar* tmp = g_get_tmp_dir();
  gchar* dir = g_build_filename(tmp, "xue_hua_video_snapshot", "covers", nullptr);
  g_mkdir_with_parents(dir, 0700);
  return dir;
}

static void handle_method_call(XueHuaVideoSnapshotPlugin* self, FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "extractCovers") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    const gchar* url = "";
    int count = 5, candidates = 15;
    double min_brightness = 0.08;
    std::string output_dir;
    if (args) {
      FlValue* v_url = fl_value_lookup_string(args, "url");
      FlValue* v_count = fl_value_lookup_string(args, "count");
      FlValue* v_cand = fl_value_lookup_string(args, "candidates");
      FlValue* v_minb = fl_value_lookup_string(args, "minBrightness");
      FlValue* v_dir = fl_value_lookup_string(args, "outputDir");
      if (v_url) url = fl_value_get_string(v_url);
      if (v_count) count = static_cast<int>(fl_value_get_int(v_count));
      if (v_cand) candidates = static_cast<int>(fl_value_get_int(v_cand));
      if (v_minb) min_brightness = fl_value_get_float(v_minb);
      if (v_dir && fl_value_get_length(v_dir) > 0) output_dir = fl_value_get_string(v_dir);
    }
    if (output_dir.empty()) { g_autofree gchar* d = default_cover_dir(); output_dir = d; }
    else g_mkdir_with_parents(output_dir.c_str(), 0700);

    auto frames = MpvCoverExtractor::ExtractCovers(url, count, candidates, min_brightness, output_dir);
    g_autoptr(FlValue) list = fl_value_new_list();
    for (const auto& f : frames) {
      g_autoptr(FlValue) m = fl_value_new_map();
      fl_value_set_string_take(m, "path", fl_value_new_string(f.path.c_str()));
      fl_value_set_string_take(m, "positionMs", fl_value_new_int(f.position_ms));
      fl_value_set_string_take(m, "brightness", fl_value_new_float(f.brightness));
      fl_value_append(list, m);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(list));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(method_call, response, nullptr);
}

static void xue_hua_video_snapshot_plugin_dispose(GObject* object) {
  auto* self = XUE_HUA_VIDEO_SNAPSHOT_PLUGIN(object);
  g_clear_object(&self->method_channel);
  G_OBJECT_CLASS(xue_hua_video_snapshot_plugin_parent_class)->dispose(object);
}

static void xue_hua_video_snapshot_plugin_class_init(XueHuaVideoSnapshotPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = xue_hua_video_snapshot_plugin_dispose;
}

static void xue_hua_video_snapshot_plugin_init(XueHuaVideoSnapshotPlugin* self) {}

static void method_call_cb(FlMethodChannel*, FlMethodCall* method_call, gpointer user_data) {
  handle_method_call(XUE_HUA_VIDEO_SNAPSHOT_PLUGIN(user_data), method_call);
}

void xue_hua_video_snapshot_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  // libmpv hard-requires LC_NUMERIC=C; otherwise mpv_create() fails outright
  // ("Non-C locale detected. This is not supported.") and downstream double
  // parsing of option strings ("50000000" etc.) can corrupt the heap and
  // abort the process with `corrupted size vs prev_size`. Set it process-wide
  // before any mpv handle is created.
  std::setlocale(LC_NUMERIC, "C");

  XueHuaVideoSnapshotPlugin* plugin = XUE_HUA_VIDEO_SNAPSHOT_PLUGIN(
      g_object_new(xue_hua_video_snapshot_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  plugin->method_channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "xue_hua_video_snapshot", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(plugin->method_channel, method_call_cb,
                                            g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
