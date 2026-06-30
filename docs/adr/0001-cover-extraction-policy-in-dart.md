# ADR-0001: Cover extraction policy in Dart

## Status

Accepted

## Context

Cover extraction policy (sampling window, Rec.601 brightness, filter, sort, trim) was
copy-pasted across five native implementations (Android, iOS/macOS, Linux/Windows mpv).
The same public interface produced different behavior — notably mpv early-stopped sampling
while Apple/Android scanned all candidate positions.

## Decision

1. Move **封面抽取策略** into a Dart `CoverExtraction` module.
2. Native code becomes a narrow **decode adapter** behind a Pigeon seam:
   `openSession`, `probeDuration`, `captureFrame` (64×64 RGBA + optional PNG path),
   `closeSession`.
3. Brightness is computed in Dart from 64×64 RGBA returned by adapters.
4. `extractCoverCandidates` throws `SnapshotException` on probe/decode failure; an empty
   list still means “no bright frames.”

## Consequences

- Policy bugs fix once; cross-platform behavior aligns.
- Dart unit tests cover sampling, luma, and sort without native binaries.
- mpv/Android sessions serialize captures per session; Dart limits concurrency to 4.
- Breaking change: callers must handle `SnapshotException`.
- Pigeon bindings must be regenerated after API changes; Swift output is copied to macOS.
