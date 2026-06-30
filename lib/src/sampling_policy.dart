/// Sample positions in milliseconds between 5% and 95% of [durationMs].
List<int> samplePositionsMs({
  required int durationMs,
  required int count,
  required int candidates,
}) {
  if (durationMs <= 0 || count <= 0) return const [];
  final budget = candidates.clamp(count, 30);
  final n = budget > count ? budget : count;
  final lower = (durationMs * 0.05).round();
  final upper = (durationMs * 0.95).round();
  final span = (upper - lower).clamp(1, durationMs);
  return List<int>.generate(n, (i) {
    return lower + (span * (i + 0.5) / n).round();
  });
}

int defaultCandidateBudget(int count) => (count * 3).clamp(count, 30);
