import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import 'commerce_notifier.dart';

final _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заявка'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => popOrGo(context, AppRoutes.cart),
        ),
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить заказ',
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        ),
        data: (order) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBadge(
                      label: order.statusLabel,
                      highlighted: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Адрес',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.address,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (order.comment != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Комментарий',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.comment!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Итого: ${formatPrice(order.totalAmount)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionTitle(title: 'Товары'),
              ...order.items.map(
                (item) => ListItem(
                  title: item.name,
                  subtitle: '${item.quantity} шт. · ${item.sku}',
                  badge: formatPrice(item.subtotal),
                  showChevron: false,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const SectionTitle(title: 'История статусов'),
              ...order.statusHistory.map(
                (entry) => ListItem(
                  title: entry.statusLabel,
                  subtitle: _dateFormat.format(entry.createdAt),
                  leading: const Icon(Icons.circle, size: 10),
                  showChevron: false,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
