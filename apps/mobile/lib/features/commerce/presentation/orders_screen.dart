import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import 'commerce_notifier.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(authProvider).isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: AppBackButton(fallback: AppRoutes.profile),
          title: const Text('Мои заказы'),
        ),
        body: const LoginRequiredView(
          title: 'Войдите по номеру',
          subtitle: 'Здесь появятся заявки после оформления',
        ),
      );
    }

    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(
          fallback: profilePathForRole(ref.watch(authProvider).user?.role),
        ),
        title: const Text('Мои заказы'),
      ),
      body: ordersAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить заказы',
          onRetry: () => ref.invalidate(ordersProvider),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Заказов пока нет',
              subtitle: 'Оформите заказ из корзины',
              actionLabel: 'В каталог',
              onAction: () => context.go(AppRoutes.catalog),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListItem(
                title: 'Заказ #${order.id.substring(0, 8)}',
                subtitle:
                    '${_dateFormat.format(order.createdAt)} · ${formatPrice(order.totalAmount)}',
                badge: order.statusLabel,
                leading: const Icon(Icons.receipt_long_outlined, size: 22),
                onTap: () => context.push(AppRoutes.orderDetail(order.id)),
              );
            },
          );
        },
      ),
    );
  }
}
