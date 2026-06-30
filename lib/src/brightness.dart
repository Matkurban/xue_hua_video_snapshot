import 'dart:typed_data';

/// Rec.601 average luma over a 64×64 RGBA buffer (straight alpha, 8-bit channels).
double rec601AverageLuma(Uint8List rgba64) {
  const size = 64 * 64;
  if (rgba64.length < size * 4) return 0.0;
  var total = 0.0;
  for (var i = 0; i < size; i++) {
    final o = i * 4;
    final r = rgba64[o] / 255.0;
    final g = rgba64[o + 1] / 255.0;
    final b = rgba64[o + 2] / 255.0;
    total += 0.299 * r + 0.587 * g + 0.114 * b;
  }
  return total / size;
}
