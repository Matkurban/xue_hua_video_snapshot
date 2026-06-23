#include <gtest/gtest.h>

#include "xue_hua_video_snapshot_plugin.h"

// This demonstrates a simple unit test of the plugin class.
TEST(XueHuaVideoSnapshotPlugin, PluginCanBeCreated) {
  auto plugin = std::make_unique<xue_hua_video_snapshot::XueHuaVideoSnapshotPlugin>();
  EXPECT_NE(plugin, nullptr);
}
