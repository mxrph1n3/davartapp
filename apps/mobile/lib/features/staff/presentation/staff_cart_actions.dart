import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import '../../commerce/data/commerce_models.dart';
import '../../commerce/presentation/commerce_notifier.dart';
import '../../commerce/presentation/project_picker_sheet.dart';
import '../data/staff_repository.dart';
import 'working_client_provider.dart';

String _addToCartErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'];
      final text = message is List
          ? message.join(', ')
          : message is String
              ? message
              : null;
      if (text != null) {
        if (text.toLowerCase().contains('out of stock')) {
          return 'Товар закончился';
        }
        if (text.toLowerCase().contains('projectid')) {
          return 'Сначала выберите проект';
        }
        if (text.toLowerCase().contains('not found')) {
          return 'Товар не найден';
        }
        return 'Не удалось добавить в корзину';
      }
    }
  }
  return 'Не удалось добавить в корзину';
}

void _showSnack(BuildContext? context, String message) {
  if (context == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Adds a product to the correct cart (own project vs working project for staff).
Future<Cart?> addProductToActiveCart(
  WidgetRef ref,
  String productId, {
  BuildContext? context,
}) async {
  if (!await promptLogin(context, ref)) return null;

  final role = ref.read(authProvider).user?.role ?? UserRole.client;

  try {
    if (role.isStudio) {
      final working = ref.read(workingClientProvider);
      if (working == null) {
        if (context != null && context.mounted) {
          _showSnack(
            context,
            'Сначала откройте клиента — товары пойдут в корзину проекта',
          );
        }
        return null;
      }

      if (context == null || !context.mounted) {
        return null;
      }

      final projectId = await ensureActiveProject(
        context,
        ref,
        staffClientId: working.id,
      );
      if (projectId == null) return null;

      final cart = await ref.read(staffRepositoryProvider).addToCart(
            projectId,
            productId: productId,
          );
      ref.invalidate(staffProjectCartProvider(projectId));
      if (context.mounted) {
        _showSnack(context, 'Добавлено в корзину');
      }
      return cart;
    }

    await ref.read(cartProvider.notifier).addProduct(productId);
    if (context != null && context.mounted) {
      _showSnack(context, 'Добавлено в корзину');
    }
    return ref.read(cartProvider).cart;
  } catch (error) {
    if (context != null && context.mounted) {
      _showSnack(context, _addToCartErrorMessage(error));
    }
    return null;
  }
}

final staffProjectCartProvider =
    FutureProvider.autoDispose.family<Cart, String>((ref, projectId) {
  return ref.watch(staffRepositoryProvider).getCart(projectId);
});
