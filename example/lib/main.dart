import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xue_hua_video_snapshot/xue_hua_video_snapshot.dart';

/// 示例应用默认测试视频（Big Buck Bunny 片段）。
const _defaultSampleUrl =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'xue_hua_video_snapshot',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      home: const CoverDemoPage(),
    );
  }
}

class CoverDemoPage extends StatefulWidget {
  const CoverDemoPage({super.key});

  @override
  State<CoverDemoPage> createState() => _CoverDemoPageState();
}

class _CoverDemoPageState extends State<CoverDemoPage> {
  final _urlController = TextEditingController(text: _defaultSampleUrl);
  final _snapshot = XueHuaVideoSnapshot.instance;

  bool _loading = false;
  String? _error;
  List<VideoCoverFrame> _frames = const [];

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _extract() async {
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请输入视频 URL 或本地路径');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _frames = const [];
    });

    try {
      final VideoSource source;
      if (text.startsWith('http://') || text.startsWith('https://')) {
        source = VideoSource.network(text);
      } else if (text.startsWith('assets/')) {
        source = VideoSource.asset(text);
      } else {
        source = VideoSource.file(text);
      }

      final frames = await _snapshot.extractCoverCandidates(
        source,
        count: 5,
        minBrightness: 0.08,
      );

      if (!mounted) return;
      setState(() {
        _frames = frames;
        if (frames.isEmpty) {
          _error = '未抽取到封面候选帧，请检查 URL 或视频内容';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('封面抽取示例')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: '视频 URL / 本地路径 / assets/...',
              border: OutlineInputBorder(),
              helperText: '支持网络地址、本地 file 路径或 Flutter asset',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _extract,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_search),
            label: Text(_loading ? '抽取中…' : '抽取封面'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_frames.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              '候选帧（${_frames.length}）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._frames.map(_buildFrameTile),
          ],
        ],
      ),
    );
  }

  Widget _buildFrameTile(VideoCoverFrame frame) {
    final path = frame.image.path;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(path),
                width: 160,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  width: 160,
                  height: 90,
                  child: ColoredBox(color: Colors.black12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('时间：${_formatDuration(frame.position)}'),
                  Text('亮度：${frame.brightness.toStringAsFixed(3)}'),
                  const SizedBox(height: 4),
                  Text(
                    path,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours}:$m:$s';
  }
}
