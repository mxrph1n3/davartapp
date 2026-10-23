import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Rounded network image with a neutral placeholder.
class PortfolioImageView extends StatelessWidget {
  const PortfolioImageView(this.url, {super.key, this.fit = BoxFit.cover});

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(color: AppColors.of(context).imagePlaceholder);
    if (url == null || url!.isEmpty) return placeholder;
    return Image.network(
      url!,
      fit: fit,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
    );
  }
}

/// «Все проекты»: many small renders overlapping, each with a white outline.
class PortfolioCollage extends StatelessWidget {
  const PortfolioCollage({super.key, required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        final shown = urls.take(9).toList();
        final rnd = math.Random(7);
        final cell = math.min(w, h) * 0.46;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(child: ColoredBox(color: colors.surfaceMuted)),
            for (var i = 0; i < shown.length; i++)
              Positioned(
                left: (i % 3) * (w - cell) / 2 + (rnd.nextDouble() - 0.5) * cell * 0.25,
                top: (i ~/ 3) * (h - cell) / 2 + (rnd.nextDouble() - 0.5) * cell * 0.25,
                width: cell,
                height: cell,
                child: Transform.rotate(
                  angle: (rnd.nextDouble() - 0.5) * 0.28,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 1.5),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                    ),
                    child: ClipRRect(borderRadius: BorderRadius.circular(4), child: PortfolioImageView(shown[i])),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Swipeable renders with a caption in the darkened bottom-left corner. The caption hides
/// while the person swipes; after a few idle seconds the card returns to the first slide.
class PortfolioCarousel extends StatefulWidget {
  const PortfolioCarousel({super.key, required this.images, required this.caption, this.onTap});

  final List<String> images;
  final Widget caption;
  final VoidCallback? onTap;

  @override
  State<PortfolioCarousel> createState() => _PortfolioCarouselState();
}

class _PortfolioCarouselState extends State<PortfolioCarousel> {
  final _pages = PageController();
  var _index = 0;
  Timer? _idle;

  @override
  void dispose() {
    _idle?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _onPage(int i) {
    setState(() => _index = i);
    _idle?.cancel();
    if (i != 0) {
      _idle = Timer(const Duration(seconds: 4), () {
        if (mounted && _pages.hasClients) {
          _pages.animateToPage(0, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: math.max(images.length, 1),
            onPageChanged: _onPage,
            itemBuilder: (_, i) => PortfolioImageView(images.isEmpty ? null : images[i]),
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _index == 0 ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomLeft,
                    radius: 1.3,
                    colors: [Color(0xB3000000), Color(0x00000000)],
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(padding: const EdgeInsets.all(14), child: widget.caption),
                ),
              ),
            ),
          ),
          if (images.length > 1)
            Positioned(
              right: 10,
              bottom: 10,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '${_index + 1} / ${images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 11.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen viewer with pinch-to-zoom.
class PortfolioViewer extends StatefulWidget {
  const PortfolioViewer({super.key, required this.images, this.initial = 0});

  final List<String> images;
  final int initial;

  static Future<void> open(BuildContext context, List<String> images, int initial) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PortfolioViewer(images: images, initial: initial),
      ),
    );
  }

  @override
  State<PortfolioViewer> createState() => _PortfolioViewerState();
}

class _PortfolioViewerState extends State<PortfolioViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late var _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              maxScale: 4,
              child: Center(child: PortfolioImageView(widget.images[i], fit: BoxFit.contain)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    '${_index + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String portfolioArea(double area) {
  final text = area == area.roundToDouble() ? area.toStringAsFixed(0) : area.toStringAsFixed(1).replaceAll('.', ',');
  return '$text м²';
}
