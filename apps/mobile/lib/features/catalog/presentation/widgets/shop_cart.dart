import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/top_notice.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../auth/presentation/require_login.dart';
import '../../../commerce/data/commerce_models.dart';
import '../../../commerce/presentation/commerce_notifier.dart';
import '../../../staff/presentation/staff_cart_actions.dart';
import '../../data/catalog_models.dart';

/// Cart line of [productId] in the client's own cart, if any.
CartItem? personalCartLine(WidgetRef ref, String productId) {
  final cart = ref.watch(cartProvider).cart;
  if (cart == null) return null;
  for (final item in cart.items) {
    if (item.product.id == productId && !item.locked) return item;
  }
  return null;
}

/// «+» and «−» from catalog lists and the product card.
///
/// Clients change their own cart; staff add to the working client's project cart
/// (the existing staff flow) — they only get «+».
class ShopCart {
  static bool isStaff(WidgetRef ref) =>
      ref.read(authProvider).user?.role.isStudio == true;

  static Future<void> add(
    BuildContext context,
    WidgetRef ref,
    ProductSummary product, {
    int packs = 1,
  }) async {
    if (isStaff(ref)) {
      await addProductToActiveCart(ref, product.id, context: context, quantity: packs);
      return;
    }
    if (!await promptLogin(context, ref)) return;
    final notifier = ref.read(cartProvider.notifier);
    final line = _line(ref, product.id);
    try {
      if (line == null) {
        await notifier.addProduct(product.id);
        if (packs > 1) {
          final added = _line(ref, product.id);
          if (added != null) await notifier.updateQuantity(added.id, packs);
        }
      } else {
        await notifier.updateQuantity(line.id, line.quantity + packs);
      }
    } catch (_) {
      if (context.mounted) showTopNotice(context, 'Не удалось добавить в корзину');
    }
  }

  static Future<void> remove(BuildContext context, WidgetRef ref, ProductSummary product) async {
    final line = _line(ref, product.id);
    if (line == null) return;
    final notifier = ref.read(cartProvider.notifier);
    try {
      if (line.quantity <= 1) {
        await notifier.removeItem(line.id);
      } else {
        await notifier.updateQuantity(line.id, line.quantity - 1);
      }
    } catch (_) {
      if (context.mounted) showTopNotice(context, 'Не удалось изменить количество');
    }
  }

  static CartItem? _line(WidgetRef ref, String productId) {
    final cart = ref.read(cartProvider).cart;
    if (cart == null) return null;
    for (final item in cart.items) {
      if (item.product.id == productId && !item.locked) return item;
    }
    return null;
  }
}

/// «2,88 м²» for pack-sold goods, «3 шт.» otherwise.
String amountLabel(ProductSummary product, int qty) =>
    packAmountLabel(product.sellByPack ? product.packSize : null, product.unit, qty);

/// Same as [amountLabel] for anything that knows its pack size (cart lines, orders).
String packAmountLabel(double? packSize, String unit, int qty) {
  if (packSize != null) {
    final total = packSize * qty;
    final text = total == total.roundToDouble()
        ? total.toStringAsFixed(0)
        : total.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll('.', ',');
    return '$text $unit';
  }
  return '$qty ${unit == 'шт' ? 'шт.' : unit}';
}

/// Main number of the counter: packs for pack-sold goods.
String qtyLabel(ProductSummary product, int qty, {bool withUnit = false}) {
  if (product.sellByPack) return withUnit ? '$qty уп.' : '$qty';
  return withUnit ? '$qty ${product.unit == 'шт' ? 'шт.' : product.unit}' : '$qty';
}
