import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'voice_waveform.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.isMine,
    required this.child,
    this.time,
  });

  final bool isMine;
  final Widget child;
  final String? time;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.accent : AppColors.surfaceMuted,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: Border.all(
            color: isMine ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            child,
            if (time != null) ...[
              const SizedBox(height: 4),
              Text(time!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.hasText,
    required this.isRecording,
    required this.recordSeconds,
    required this.recordBars,
    required this.onRecordStart,
    required this.onRecordStop,
    required this.onRecordCancel,
    this.isSending = false,
    this.onTyping,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final bool hasText;
  final bool isRecording;
  final int recordSeconds;
  final List<double> recordBars;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordStop;
  final VoidCallback onRecordCancel;
  final bool isSending;
  final ValueChanged<String>? onTyping;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  var _willCancel = false;

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isRecording && _willCancel) {
      _willCancel = false;
    }
  }

  void _endHold() {
    if (!widget.isRecording) return;
    if (_willCancel) {
      widget.onRecordCancel();
    } else {
      widget.onRecordStop();
    }
    setState(() => _willCancel = false);
  }

  @override
  Widget build(BuildContext context) {
    final minutes = widget.recordSeconds ~/ 60;
    final seconds = widget.recordSeconds % 60;
    final clock = '$minutes:${seconds.toString().padLeft(2, '0')}';
    final liveBars = widget.recordBars.isEmpty
        ? const [0.18, 0.32, 0.22, 0.4]
        : widget.recordBars.length > 36
            ? widget.recordBars.sublist(widget.recordBars.length - 36)
            : widget.recordBars;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          if (widget.isRecording)
            IconButton(
              onPressed: widget.onRecordCancel,
              icon: Icon(
                _willCancel ? Icons.delete : Icons.delete_outline,
                color: AppColors.error,
              ),
            )
          else
            IconButton(
              onPressed: widget.isSending ? null : widget.onAttach,
              icon: const Icon(Icons.add, size: 24),
              color: AppColors.textPrimary,
            ),
          Expanded(
            child: widget.isRecording
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VoiceWaveform(
                        bars: liveBars,
                        progress: 1,
                        height: 26,
                        playedColor: _willCancel
                            ? AppColors.error
                            : AppColors.textPrimary,
                        unplayedColor: AppColors.textPrimary.withValues(
                          alpha: 0.2,
                        ),
                      ),
                      Text(
                        _willCancel ? 'Отпустите, чтобы удалить' : clock,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _willCancel
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                      ),
                    ],
                  )
                : TextField(
                    controller: widget.controller,
                    enabled: !widget.isSending,
                    decoration: InputDecoration(
                      hintText: widget.isSending ? 'Отправка…' : 'Сообщение',
                      hintStyle: Theme.of(context).textTheme.bodyMedium,
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.inputRadius,
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    minLines: 1,
                    maxLines: 4,
                    onChanged: widget.onTyping,
                    onSubmitted: (_) => widget.onSend(),
                  ),
          ),
          const SizedBox(width: 4),
          if (widget.hasText && !widget.isRecording && !widget.isSending)
            Material(
              color: AppColors.textPrimary,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: widget.onSend,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.arrow_upward,
                    size: 20,
                    color: AppColors.background,
                  ),
                ),
              ),
            )
          else if (widget.isSending)
            const SizedBox(
              width: 48,
              height: 48,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            GestureDetector(
              onTap: widget.isRecording
                  ? widget.onRecordStop
                  : widget.onRecordStart,
              onLongPressStart: (_) {
                setState(() => _willCancel = false);
                widget.onRecordStart();
              },
              onLongPressMoveUpdate: (details) {
                final cancel = details.offsetFromOrigin.dx < -64;
                if (cancel != _willCancel) {
                  setState(() => _willCancel = cancel);
                }
              },
              onLongPressEnd: (_) => _endHold(),
              child: AnimatedScale(
                scale: widget.isRecording ? 1.18 : 1,
                duration: const Duration(milliseconds: 160),
                child: Material(
                  color: widget.isRecording
                      ? (_willCancel ? AppColors.error : AppColors.accent)
                      : AppColors.accent,
                  shape: const CircleBorder(),
                  elevation: widget.isRecording ? 4 : 0,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      widget.isRecording
                          ? (_willCancel ? Icons.delete : Icons.mic)
                          : Icons.mic,
                      size: 24,
                      color: widget.isRecording && _willCancel
                          ? AppColors.background
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
