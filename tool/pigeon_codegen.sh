#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
dart run pigeon --input lib/pigeons/video_decoder_api.dart
"$ROOT/tool/sync_apple_spm_sources.sh"
"$ROOT/tool/patch_pigeon_int64.sh"
