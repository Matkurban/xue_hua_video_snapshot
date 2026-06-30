#!/usr/bin/env bash
# Patches generated Pigeon handlers to coerce int64 session/position args safely.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

patch_swift() {
  local f="$1"
  sed -i '' \
    -e 's/let sessionIdArg = args\[0\] as! Int64/let sessionIdArg = PigeonCodecHelpers.int64(from: args[0])/g' \
    -e 's/let positionMsArg = args\[1\] as! Int64/let positionMsArg = PigeonCodecHelpers.int64(from: args[1])/g' \
    "$f"
}

for f in \
  "$ROOT/lib/shared/apple/VideoDecoderApi.swift" \
  "$ROOT/ios/xue_hua_video_snapshot/Sources/xue_hua_video_snapshot/VideoDecoderApi.swift" \
  "$ROOT/macos/xue_hua_video_snapshot/Sources/xue_hua_video_snapshot/VideoDecoderApi.swift"; do
  patch_swift "$f"
done

patch_kotlin() {
  local f="$ROOT/android/src/main/kotlin/com/kurban/xue_hua_video_snapshot/VideoDecoderApi.kt"
  sed -i '' \
    -e 's/val sessionIdArg = args\[0\] as Long/val sessionIdArg = pigeonLong(args[0])/g' \
    -e 's/val positionMsArg = args\[1\] as Long/val positionMsArg = pigeonLong(args[1])/g' \
    "$f"
}

patch_kotlin
echo "Patched Pigeon int64 coercions (Swift + Kotlin)"
