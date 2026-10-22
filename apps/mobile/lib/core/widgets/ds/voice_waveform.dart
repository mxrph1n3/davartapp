import 'package:flutter/material.dart';

class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    super.key,
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    this.onSeek,
    this.height = 28,
  });

  final List<double> bars;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final ValueChanged<double>? onSeek;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: onSeek == null
          ? null
          : (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null || box.size.width <= 0) return;
              onSeek!((details.localPosition.dx / box.size.width).clamp(0, 1));
            },
      child: SizedBox(
        height: height,
        width: 168,
        child: CustomPaint(
          painter: _WaveformPainter(
            bars: bars.isEmpty ? const [0.2, 0.4, 0.3] : bars,
            progress: progress.clamp(0, 1),
            playedColor: playedColor,
            unplayedColor: unplayedColor,
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  final List<double> bars;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 2.0;
    final count = bars.length;
    final barWidth = ((size.width - gap * (count - 1)) / count).clamp(1.6, 3.2);
    final totalWidth = count * barWidth + (count - 1) * gap;
    final originX = (size.width - totalWidth) / 2;
    final playedUntil = originX + totalWidth * progress;

    for (var i = 0; i < count; i++) {
      final x = originX + i * (barWidth + gap);
      final barHeight = (8 + bars[i].clamp(0.08, 1) * (size.height - 8));
      final y = (size.height - barHeight) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(1.5),
      );
      final paint = Paint()
        ..color = x + barWidth / 2 <= playedUntil ? playedColor : unplayedColor;
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.bars != bars ||
        oldDelegate.progress != progress ||
        oldDelegate.playedColor != playedColor ||
        oldDelegate.unplayedColor != unplayedColor;
  }
}
