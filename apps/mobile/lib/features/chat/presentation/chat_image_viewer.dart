import 'package:flutter/material.dart';

/// Full-screen image viewer with pinch-zoom (Telegram-style).
class ChatImageViewer extends StatelessWidget {
  const ChatImageViewer({super.key, required this.url, this.title});

  final String url;
  final String? title;

  static Future<void> open(
    BuildContext context, {
    required String url,
    String? title,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => ChatImageViewer(url: url, title: title),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: title == null
            ? null
            : Text(
                title!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                height: 120,
                width: 120,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            },
            errorBuilder: (_, _, _) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                SizedBox(height: 12),
                Text(
                  'Не удалось загрузить фото',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
