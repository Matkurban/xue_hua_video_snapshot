import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_video_snapshot/xue_hua_video_snapshot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('extractCoverCandidates from bundled asset', (tester) async {
    final snapshot = XueHuaVideoSnapshot.instance;
    final frames = await snapshot.extractCoverCandidates(
      const VideoSource.asset('assets/videos/sample.mp4'),
      count: 2,
      minBrightness: 0.01,
    );
    expect(frames, isNotEmpty);
    for (final frame in frames) {
      expect(frame.brightness, greaterThan(0.0));
      expect(await frame.image.length(), greaterThan(0));
    }
  });
}
