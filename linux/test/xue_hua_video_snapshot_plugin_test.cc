#include <gtest/gtest.h>

#include "include/xue_hua_video_snapshot/xue_hua_video_snapshot_plugin.h"

// This demonstrates a simple unit test of the plugin registration.
TEST(XueHuaVideoSnapshotPlugin, PluginRegistration) {
  EXPECT_NE(xue_hua_video_snapshot_plugin_get_type, nullptr);
}
