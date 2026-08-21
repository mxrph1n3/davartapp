import 'dart:convert';
import 'dart:math';

class VoiceMeta {
  const VoiceMeta({
    required this.durationSec,
    required this.bars,
  });

  final int durationSec;
  final List<double> bars;

  static VoiceMeta parse(String? content, {int? fallbackDuration}) {
    final raw = content?.trim();
    if (raw == null || raw.isEmpty) {
      return VoiceMeta(
        durationSec: fallbackDuration ?? 0,
        bars: syntheticBars(fallbackDuration ?? 8),
      );
    }

    if (!raw.startsWith('{')) {
      final seconds = int.tryParse(raw) ?? fallbackDuration ?? 0;
      return VoiceMeta(durationSec: seconds, bars: syntheticBars(seconds));
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final seconds = (json['d'] as num?)?.toInt() ?? fallbackDuration ?? 0;
      final encoded = json['w'];
      final bars = <double>[];
      if (encoded is List) {
        for (final item in encoded) {
          if (item is num) bars.add((item.toDouble() / 31).clamp(0.08, 1));
        }
      }
      return VoiceMeta(
        durationSec: seconds,
        bars: bars.isEmpty ? syntheticBars(seconds) : bars,
      );
    } catch (_) {
      return VoiceMeta(
        durationSec: fallbackDuration ?? 0,
        bars: syntheticBars(fallbackDuration ?? 8),
      );
    }
  }

  String encode() {
    final packed = bars
        .take(48)
        .map((bar) => (bar.clamp(0, 1) * 31).round().clamp(0, 31))
        .toList();
    return jsonEncode({'d': durationSec, 'w': packed});
  }

  static List<double> downsample(List<double> peaks, {int count = 40}) {
    if (peaks.isEmpty) return List<double>.filled(count, 0.12);
    if (peaks.length <= count) return List<double>.from(peaks);

    final result = <double>[];
    final bucket = peaks.length / count;
    for (var i = 0; i < count; i++) {
      final start = (i * bucket).floor();
      final end = min(peaks.length, ((i + 1) * bucket).ceil());
      var maxVal = 0.08;
      for (var j = start; j < end; j++) {
        maxVal = max(maxVal, peaks[j]);
      }
      result.add(maxVal);
    }
    return result;
  }

  static List<double> syntheticBars(int durationSec) {
    final count = min(40, max(18, durationSec * 3));
    final random = Random(durationSec + 17);
    return List<double>.generate(count, (index) {
      final wave = (sin(index * 0.55) + 1) / 2;
      return (0.18 + wave * 0.55 + random.nextDouble() * 0.2).clamp(0.12, 1);
    });
  }
}
