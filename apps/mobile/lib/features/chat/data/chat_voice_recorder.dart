import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'voice_meta.dart';

class ChatVoiceTake {
  const ChatVoiceTake({
    required this.bytes,
    required this.durationSec,
    required this.fileName,
    required this.bars,
  });

  final List<int> bytes;
  final int durationSec;
  final String fileName;
  final List<double> bars;

  String get content =>
      VoiceMeta(durationSec: durationSec, bars: bars).encode();
}

class ChatVoiceRecorder {
  final _recorder = AudioRecorder();
  final _peaks = <double>[];
  DateTime? _startedAt;
  String? _path;
  StreamSubscription<Amplitude>? _amplitudeSub;
  void Function(List<double> peaks)? onPeaks;

  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;

    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    _startedAt = DateTime.now();
    _peaks.clear();

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: _path!,
    );

    await _amplitudeSub?.cancel();
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((amplitude) {
      final normalized = ((amplitude.current + 52) / 48).clamp(0.08, 1.0);
      _peaks.add(normalized);
      onPeaks?.call(List<double>.unmodifiable(_peaks));
    });
    return true;
  }

  Future<ChatVoiceTake?> stop() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    final path = await _recorder.stop() ?? _path;
    final startedAt = _startedAt;
    final peaks = List<double>.from(_peaks);
    _startedAt = null;
    _path = null;
    _peaks.clear();
    if (path == null || startedAt == null) return null;

    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    await file.delete();

    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    if (bytes.isEmpty || elapsedMs < 400) return null;
    final durationSec = (elapsedMs / 1000).ceil().clamp(1, 3600);

    return ChatVoiceTake(
      bytes: bytes,
      durationSec: durationSec,
      fileName: 'voice.m4a',
      bars: VoiceMeta.downsample(peaks),
    );
  }

  Future<void> cancel() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _peaks.clear();
    final path = await _recorder.stop() ?? _path;
    _startedAt = null;
    _path = null;
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> dispose() async {
    await _amplitudeSub?.cancel();
    try {
      await _recorder.dispose();
    } catch (_) {}
  }
}
