import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds/voice_waveform.dart';
import '../data/voice_meta.dart';

class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({
    super.key,
    required this.url,
    this.content,
    this.isMine = false,
  });

  final String url;
  final String? content;
  final bool isMine;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final _player = AudioPlayer();
  var _playing = false;
  var _speed = 1.0;
  Duration _position = Duration.zero;
  Duration? _duration;

  VoiceMeta get _meta => VoiceMeta.parse(widget.content);

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state.playing);
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
    _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _player.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _ensureSource() async {
    if (_player.audioSource != null) return;
    await _player.setUrl(widget.url);
    await _player.setSpeed(_speed);
  }

  Future<void> _toggle() async {
    if (widget.url.isEmpty) return;
    await _ensureSource();
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _seek(double progress) async {
    await _ensureSource();
    final total = _total;
    if (total.inMilliseconds <= 0) return;
    await _player.seek(
      Duration(milliseconds: (total.inMilliseconds * progress).round()),
    );
  }

  Future<void> _cycleSpeed() async {
    final next = switch (_speed) {
      1.0 => 1.5,
      1.5 => 2.0,
      _ => 1.0,
    };
    setState(() => _speed = next);
    await _ensureSource();
    await _player.setSpeed(next);
  }

  Duration get _total {
    if (_duration != null && _duration!.inMilliseconds > 0) return _duration!;
    return Duration(seconds: _meta.durationSec);
  }

  double get _progress {
    final total = _total.inMilliseconds;
    if (total <= 0) return 0;
    return (_position.inMilliseconds / total).clamp(0, 1);
  }

  String get _label {
    final showPosition = _playing || _position.inMilliseconds > 400;
    final seconds =
        showPosition ? _position.inSeconds : _total.inSeconds;
    return _format(seconds);
  }

  String _format(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    return '${safe ~/ 60}:${(safe % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final playFill = widget.isMine ? AppColors.textPrimary : AppColors.accent;
    final playIcon = widget.isMine ? AppColors.background : AppColors.textPrimary;
    final played = AppColors.textPrimary;
    final unplayed = AppColors.textPrimary.withValues(alpha: widget.isMine ? 0.28 : 0.22);

    return SizedBox(
      width: 214,
      child: Row(
        children: [
          Material(
            color: playFill,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _toggle,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 26,
                  color: playIcon,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VoiceWaveform(
                  bars: _meta.bars,
                  progress: _playing || _position.inMilliseconds > 0
                      ? _progress
                      : 0,
                  playedColor: played,
                  unplayedColor: unplayed,
                  onSeek: _seek,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _cycleSpeed,
                      child: Text(
                        switch (_speed) {
                          1.0 => '1x',
                          2.0 => '2x',
                          _ => '1.5x',
                        },
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
