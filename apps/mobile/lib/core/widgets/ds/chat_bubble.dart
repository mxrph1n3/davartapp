import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'voice_waveform.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.isMine,
    required this.child,
    this.time,
    this.showTail = true,
    this.pending = false,
    this.failed = false,
    this.onFailedTap,
  });

  final bool isMine;
  final Widget child;
  final String? time;
  final bool showTail;
  final bool pending;
  final bool failed;
  final VoidCallback? onFailedTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = isMine
        ? (dark ? const Color(0xFF2B5278) : colors.chatBubbleMine)
        : (dark ? const Color(0xFF182533) : colors.chatBubbleTheirs);
    final fg = isMine
        ? (dark ? Colors.white : colors.chatBubbleMineFg)
        : colors.textPrimary;
    final timeColor = fg.withValues(alpha: isMine ? 0.72 : 0.6);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: fg,
              fontSize: 16,
              height: 1.25,
            ),
        child: IconTheme(
          data: IconThemeData(color: fg, size: 20),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            margin: EdgeInsets.only(
              bottom: showTail ? 8 : 2,
              left: isMine ? 48 : 6,
              right: isMine ? 6 : 48,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(!isMine && showTail ? 4 : 16),
                      bottomRight: Radius.circular(isMine && showTail ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      child,
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (time != null)
                              Text(
                                time!,
                                style: TextStyle(
                                  color: timeColor,
                                  fontSize: 11,
                                  height: 1,
                                ),
                              ),
                            if (isMine) ...[
                              const SizedBox(width: 3),
                              Icon(
                                pending ? Icons.access_time : Icons.done,
                                size: 14,
                                color: timeColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (failed)
                  Positioned(
                    top: -6,
                    right: isMine ? -6 : null,
                    left: isMine ? null : -6,
                    child: GestureDetector(
                      onTap: onFailedTap,
                      child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: colors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.background, width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          '!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                      ),
                    ),
                if (showTail)
                  Positioned(
                    bottom: 0,
                    left: isMine ? null : -5,
                    right: isMine ? -5 : null,
                    child: CustomPaint(
                      size: const Size(8, 12),
                      painter: _BubbleTailPainter(color: bg, mine: isMine),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.color, required this.mine});

  final Color color;
  final bool mine;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (mine) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.mine != mine;
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
    final colors = AppColors.of(context);
    final minutes = widget.recordSeconds ~/ 60;
    final seconds = widget.recordSeconds % 60;
    final clock = '$minutes:${seconds.toString().padLeft(2, '0')}';
    final liveBars = widget.recordBars.isEmpty
        ? const [0.18, 0.32, 0.22, 0.4]
        : widget.recordBars.length > 36
            ? widget.recordBars.sublist(widget.recordBars.length - 36)
            : widget.recordBars;

    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final safeBottom = keyboardOpen ? 0.0 : MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(4, 6, 6, 6 + safeBottom),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          if (widget.isRecording)
            IconButton(
              onPressed: widget.onRecordCancel,
              icon: Icon(
                _willCancel ? Icons.delete : Icons.delete_outline,
                color: colors.error,
              ),
            )
          else
            IconButton(
              onPressed: widget.isSending ? null : widget.onAttach,
              icon: const Icon(Icons.attach_file, size: 24),
              color: colors.textPrimary,
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
                            ? colors.error
                            : colors.textPrimary,
                        unplayedColor: colors.textPrimary.withValues(
                          alpha: 0.2,
                        ),
                      ),
                      Text(
                        _willCancel ? 'Отпустите, чтобы удалить' : clock,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _willCancel
                                  ? colors.error
                                  : colors.textSecondary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                    ],
                  )
                : TextField(
                    controller: widget.controller,
                    enabled: !widget.isSending,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: widget.isSending ? 'Отправка…' : 'Сообщение',
                      hintStyle: Theme.of(context).textTheme.bodyMedium,
                      filled: true,
                      fillColor: colors.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
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
              color: colors.textPrimary,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: widget.onSend,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.arrow_upward,
                    size: 20,
                    color: colors.background,
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
                      ? (_willCancel ? colors.error : colors.accent)
                      : colors.accent,
                  shape: const CircleBorder(),
                  elevation: widget.isRecording ? 4 : 0,
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      widget.isRecording && _willCancel
                          ? Icons.delete
                          : Icons.mic,
                      size: 20,
                      color: widget.isRecording && _willCancel
                          ? colors.background
                          : colors.textOnAccent,
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
