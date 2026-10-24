import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/top_notice.dart';
import '../data/profile_repository.dart';
import 'profile_notifier.dart';

/// Own avatar with a camera badge: tap to take or pick a photo, or remove it.
class AvatarPicker extends ConsumerStatefulWidget {
  const AvatarPicker({
    super.key,
    required this.label,
    this.imageUrl,
    this.size = 72,
  });

  final String label;
  final String? imageUrl;
  final double size;

  @override
  ConsumerState<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<AvatarPicker> {
  var _busy = false;

  Future<void> _choose() async {
    final hasPhoto = widget.imageUrl?.isNotEmpty == true;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Сделать фото'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Выбрать из галереи'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Удалить фото'),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    final repo = ref.read(profileRepositoryProvider);
    setState(() => _busy = true);
    try {
      if (action == 'remove') {
        await repo.removeAvatar();
      } else {
        final file = await ImagePicker().pickImage(
          source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        if (file == null) return;
        await repo.uploadAvatar(file.path);
      }
      ref.invalidate(profileProvider);
    } catch (_) {
      if (mounted) showTopNotice(context, 'Не удалось обновить фото');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: _busy ? null : _choose,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AppAvatar(label: widget.label, imageUrl: widget.imageUrl, size: widget.size),
          if (_busy)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
              child: Icon(Icons.photo_camera_outlined, size: 15, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
