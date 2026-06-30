#!/usr/bin/env bash
# Sync lib/shared/apple into iOS/macOS Swift Package Manager targets.
#
# Pigeon generates swiftOut under lib/shared/apple/. CocoaPods includes that path
# via podspec source_files. SPM requires sources inside each Package.swift target.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/lib/shared/apple"
for dest in \
  "$ROOT/ios/xue_hua_video_snapshot/Sources/xue_hua_video_snapshot" \
  "$ROOT/macos/xue_hua_video_snapshot/Sources/xue_hua_video_snapshot"; do
  cp "$SRC/VideoDecoderApi.swift" \
     "$SRC/AppleVideoDecoderHostApi.swift" \
     "$SRC/PigeonCodecHelpers.swift" \
     "$dest/"
done
echo "Synced lib/shared/apple → ios/ and macos/ SPM Sources"
