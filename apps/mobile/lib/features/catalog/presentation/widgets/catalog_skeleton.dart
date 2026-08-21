import 'package:flutter/material.dart';

class CatalogSkeleton extends StatelessWidget {
  const CatalogSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) =>
                  const _SkeletonBox(width: 96, height: 36),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.separated(
            itemCount: 6,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) => const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 112, height: 112),
                SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 112,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(height: 18),
                        SizedBox(height: 8),
                        _SkeletonBox(width: 120, height: 14),
                        SizedBox(height: 8),
                        _SkeletonBox(height: 14),
                        Spacer(),
                        _SkeletonBox(width: 80, height: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({this.width, required this.height});

  final double? width;
  final double height;

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0xFFECE8E1),
              const Color(0xFFF7F4EF),
              _controller.value,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }
}
